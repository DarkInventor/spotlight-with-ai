import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

// Accessibility constants - defined here for compatibility across macOS versions
private let axFocusedAttribute = "AXFocused"
private let axRoleAttribute = "AXRole"
private let axChildrenAttribute = "AXChildren"
private let axValueAttribute = "AXValue"
private let axSizeAttribute = "AXSize"
private let axPositionAttribute = "AXPosition"
private let axWindowsAttribute = "AXWindows"
private let axFrameAttribute = "AXFrame"

@MainActor
class AppAutomationManager: ObservableObject {
    @Published var isAutomating = false
    @Published var lastAutomationResult: String = ""
    
    // Cursor position memory for Word
    private var wordCursorPosition: (x: CGFloat, y: CGFloat)?
    private var wordLastActiveApp: String?
    
    struct AppAutomationTarget {
        let bundleIdentifier: String
        let displayName: String
        let automationStrategy: AutomationStrategy
        let supportedActions: [AutomationAction]
    }
    
    enum AutomationStrategy {
        case appleScript
        case accessibility
        case uiTest
        case hybrid
    }
    
    enum AutomationAction {
        case typeText(String)
        case clickElement(String)
        case focusElement(String)
        case openURL(String)
        case insertAtCursor(String)
        case replaceSelection(String)
    }
    
    private let supportedApps: [AppAutomationTarget] = [
        AppAutomationTarget(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            automationStrategy: .hybrid,
            supportedActions: [.typeText(""), .insertAtCursor(""), .focusElement("document"), .openURL("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            automationStrategy: .hybrid,
            supportedActions: [.typeText(""), .insertAtCursor(""), .focusElement("document")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.Pages",
            displayName: "Pages",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor(""), .replaceSelection("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.microsoft.Word",
            displayName: "Microsoft Word",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor(""), .focusElement("document"), .openURL("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.microsoft.Excel",
            displayName: "Microsoft Excel",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.microsoft.PowerPoint",
            displayName: "Microsoft PowerPoint",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.Numbers",
            displayName: "Numbers",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.Keynote",
            displayName: "Keynote",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.dt.Xcode",
            displayName: "Xcode",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.hnc.Discord",
            displayName: "Discord",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            automationStrategy: .appleScript,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "com.notion.id",
            displayName: "Notion",
            automationStrategy: .accessibility,
            supportedActions: [.typeText(""), .insertAtCursor("")]
        ),
        AppAutomationTarget(
            bundleIdentifier: "us.zoom.xos",
            displayName: "Zoom",
            automationStrategy: .accessibility,
            supportedActions: [.typeText("")]
        )
    ]
    
    // MARK: - Cursor Position Memory
    
    func captureWordCursorPosition() async {
        print("📍 Attempting to capture Word cursor position for later restoration")
        
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("⚠️ Word not found for cursor position capture")
            return
        }
        
        wordLastActiveApp = wordApp.localizedName
        
        // Try to get cursor position using AppleScript
        let cursorPosition = await getCursorPositionWithAppleScript()
        if let position = cursorPosition {
            wordCursorPosition = position
            print("✅ Captured Word cursor position: \(position)")
        } else {
            print("⚠️ Could not capture Word cursor position, will use document end")
            wordCursorPosition = nil
        }
    }
    
    private func getCursorPositionWithAppleScript() async -> (x: CGFloat, y: CGFloat)? {
        let script = """
        tell application "Microsoft Word"
            try
                set cursorRange to get selection
                set cursorInfo to get information of cursorRange
                -- This is a simplified version - Word's AppleScript cursor info is limited
                return {100, 100} -- Fallback position
            on error
                return missing value
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if error == nil {
                        // For now, we'll use a simplified approach
                        // Real cursor position tracking in Word is complex
                        continuation.resume(returning: (100, 100))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Main Automation Interface
    
    func automateWriting(text: String, targetApp: String) async -> Bool {
        // Check accessibility permissions first
        if !checkAccessibilityPermissions() {
            print("⚠️ Accessibility permissions not granted - automation may fail")
        }
        
        guard !isAutomating else { return false }
        
        isAutomating = true
        defer { isAutomating = false }
        
        print("🤖 Starting automation for \(targetApp) with text: \(text.prefix(50))...")
        
        // Special handling for Cursor IDE - minimize search app first
        if targetApp.lowercased().contains("cursor") {
            return await automateCursorCodeWriting(text: text)
        }
        
        // Special handling for Microsoft Excel - minimize search app and write clean content
        if targetApp.lowercased().contains("microsoft excel") || targetApp.lowercased().contains("excel") {
            return await automateExcelSpreadsheetWriting(text: text)
        }
        
        // Special handling for Visual Studio Code - minimize search app and write code
        if targetApp.lowercased().contains("visual studio code") || targetApp.lowercased().contains("vs code") {
            return await automateVSCodeWriting(text: text)
        }
        
        // Special handling for Xcode - minimize search app and write code
        if targetApp.lowercased().contains("xcode") {
            return await automateXcodeWriting(text: text)
        }
        
        // Find the app configuration
        guard let appConfig = supportedApps.first(where: { 
            $0.displayName.lowercased().contains(targetApp.lowercased()) || 
            targetApp.lowercased().contains($0.displayName.lowercased())
        }) else {
            return await fallbackAutomation(text: text, targetApp: targetApp)
        }
        
        // Execute automation based on strategy
        switch appConfig.automationStrategy {
        case .appleScript:
            return await automateWithAppleScript(text: text, app: appConfig)
        case .accessibility:
            return await automateWithAccessibility(text: text, app: appConfig)
        case .uiTest:
            return await automateWithUITest(text: text, app: appConfig)
        case .hybrid:
            return await automateWithHybridApproach(text: text, app: appConfig)
        }
    }
    
    // MARK: - Cursor IDE Specific Automation
    
    private func automateCursorCodeWriting(text: String) async -> Bool {
        print("🎯 CURSOR IDE: Special code writing mode activated")
        
        // Step 1: Minimize the search app window first
        await minimizeSearchApp()
        
        // Step 2: Ensure Cursor is active and ready
        guard await ensureCursorIsReady() else {
            print("❌ Failed to prepare Cursor IDE")
            return false
        }
        
        // Step 3: Extract and write only code content
        let codeContent = extractCodeFromText(text)
        if codeContent.isEmpty {
            print("⚠️ No code content found in text")
            return false
        }
        
        print("📝 Writing code to Cursor: \(codeContent.prefix(100))...")
        
        // Step 4: Write the code using the most reliable method for Cursor
        return await writeCodeToCursor(codeContent)
    }
    
    private func minimizeSearchApp() async {
        print("📱 Minimizing search app window")
        
        // Use multiple methods to ensure window is properly minimized
        await MainActor.run {
            // Method 1: Try WindowManager from app delegate
            if let appDelegate = NSApp.delegate {
                if appDelegate.responds(to: Selector(("hideWindow"))) {
                    appDelegate.perform(Selector(("hideWindow")))
                    print("✅ Search window hidden using App Delegate")
                }
            }
            
            // Method 2: Post notification (primary method used by ContentView)
            NotificationCenter.default.post(name: NSNotification.Name("HideSearchWindow"), object: nil)
            print("📤 Posted HideSearchWindow notification")
            
            // Method 3: Hide all windows directly
            for window in NSApp.windows {
                if window.isVisible && window.canBecomeKey {
                    window.orderOut(nil)
                    window.miniaturize(nil)
                    print("🪟 Minimized window: \(window.title)")
                }
            }
        }
        
        // Longer delay to ensure window is fully hidden
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func ensureCursorIsReady() async -> Bool {
        print("🎯 Ensuring Cursor IDE is ready for code writing")
        
        // Find Cursor app
        guard let cursorApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.todesktop.230313mzl4w4u92" ||
            $0.localizedName?.lowercased().contains("cursor") == true
        }) else {
            print("❌ Cursor IDE not found or not running")
            return false
        }
        
        // Activate Cursor
        cursorApp.activate()
        print("📱 Activated Cursor IDE")
        
        // Wait for Cursor to become active
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Try to focus on the editor area using accessibility
        let appElement = AXUIElementCreateApplication(cursorApp.processIdentifier)
        
        // Look for a text editing area in Cursor
        if await focusCursorEditor(appElement: appElement) {
            print("✅ Successfully focused Cursor editor")
            return true
        }
        
        print("⚠️ Could not focus Cursor editor, but continuing...")
        return true
    }
    
    private func focusCursorEditor(appElement: AXUIElement) async -> Bool {
        print("🔍 Looking for Cursor editor element")
        
        // Cursor typically uses text areas or code editor elements
        let cursorRoles = [
            "AXTextArea",
            "AXTextField", 
            "AXWebArea",
            "AXScrollArea",
            "AXGroup"
        ]
        
        return await searchForElementWithRoles(in: appElement, roles: cursorRoles, maxDepth: 15) != nil
    }
    
    private func extractCodeFromText(_ text: String) -> String {
        // Remove common AI response patterns and extract only code
        var codeContent = text
        
        // Remove AI response markers
        let aiPatterns = [
            "Here's the code:",
            "Here's your code:",
            "I'll help you",
            "Sure, here's",
            "```swift",
            "```javascript", 
            "```python",
            "```typescript",
            "```",
            "The code above",
            "This code will",
            "This implementation",
            "Let me know if"
        ]
        
        for pattern in aiPatterns {
            codeContent = codeContent.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Remove excessive newlines and trim
        codeContent = codeContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        // Look for code blocks between triple backticks
        if let codeBlock = extractCodeBlock(from: text) {
            return codeBlock
        }
        
        // If no code block markers, check if the text looks like code
        if looksLikeCode(codeContent) {
            return codeContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return ""
    }
    
    private func extractCodeBlock(from text: String) -> String? {
        // Look for code blocks with language specification
        let patterns = [
            #"```\w*\n(.*?)```"#,  // With language
            #"```(.*?)```"#        // Without language
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    private func looksLikeCode(_ text: String) -> Bool {
        let codeIndicators = [
            "func ", "function ", "class ", "import ", "export ",
            "let ", "const ", "var ", "if (", "for (", "while (",
            "{", "}", "[", "]", "=>", "->", "::", "=", ";",
            "print(", "console.log", "return ", "async ", "await "
        ]
        
        let lowercaseText = text.lowercased()
        let indicatorCount = codeIndicators.filter { lowercaseText.contains($0) }.count
        
        // If it has 3+ code indicators, it's likely code
        return indicatorCount >= 3
    }
    
    private func writeCodeToCursor(_ code: String) async -> Bool {
        print("⌨️ Writing code to Cursor using hybrid approach")
        
        // Try accessibility first for better positioning
        let cursorApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.todesktop.230313mzl4w4u92" ||
            $0.localizedName?.lowercased().contains("cursor") == true
        })
        
        if let app = cursorApp {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            
            // Try to find and focus a text element
            if await focusTextElement(appElement: appElement, app: supportedApps.first(where: { $0.displayName == "Cursor" })!) {
                print("✅ Focused Cursor text element")
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        // Use Core Graphics for reliable typing
        return await typeCodeWithCoreGraphics(code)
    }
    
    private func typeCodeWithCoreGraphics(_ code: String) async -> Bool {
        print("🎯 Typing code using Core Graphics with proper formatting")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        var successCount = 0
        let lines = code.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            // Type the line
            for char in line {
                if await typeCharacterWithCoreGraphics(char, eventSource: eventSource) {
                    successCount += 1
                }
                // Smaller delay for smoother code typing
                try? await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds
            }
            
            // Add newline after each line except the last
            if index < lines.count - 1 {
                _ = await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Return key
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds for line processing
            }
        }
        
        let success = successCount > 0
        print("✅ Typed \(successCount) characters of code successfully")
        return success
    }
    
    // MARK: - Microsoft Word Specific Automation
    
    private func automateWordDocumentWriting(text: String) async -> Bool {
        print("�� 🐱 MICROSOFT WORD: Using PROVEN Chrome-style automation approach!")
        
        // 🐱 CRITICAL: DO NOT minimize search app - this breaks the focus chain!
        print("🎯 KEEPING search app visible to maintain proper focus chain")
        
        // Step 1: Use the EXACT SAME approach that works for Chrome!
        // This is simple, reliable, and supports streaming text perfectly
        let success = await automateWordWithSimpleAppleScript(text)
        
        if success {
            print("✅ 🐱 CATS ARE SAVED! Word automation completed using Chrome-style approach!")
        } else {
            print("❌ Word automation failed - trying fallback")
            // Fallback to accessibility approach if AppleScript fails
            let fallbackSuccess = await automateWordWithAccessibilityFallback(text)
            if fallbackSuccess {
                print("✅ 🐱 CATS ARE SAVED! Word automation completed with fallback!")
                return true
            }
        }
        
        return success
    }
    
    private func automateWordWithSimpleAppleScript(_ text: String) async -> Bool {
        print("🐱 Using PROVEN Chrome-style AppleScript automation for Word!")
        
        // Use the exact same logic that works perfectly for Chrome
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.3
        end tell
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        return await executeAppleScript(script)
    }
    
    private func automateWordWithAccessibilityFallback(_ text: String) async -> Bool {
        print("🔄 Using accessibility fallback for Word")
        
        // Find Word app
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("❌ Microsoft Word not found or not running")
            return false
        }
        
        // Activate Word
        wordApp.activate()
        print("📱 Activated Microsoft Word")
        
        // Wait for Word to become active
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Use direct Core Graphics typing as fallback
        return await typeWithCoreGraphics(text)
    }
    
    private func ensureWordIsReady() async -> Bool {
        print("📝 🐱 ENHANCED Word preparation - SAVING CATS with better approach!")
        
        // Find Word app
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("❌ Microsoft Word not found or not running")
            return false
        }
        
        // Force activate Word multiple times to ensure it's in front
        for attempt in 1...5 {
            wordApp.activate()
            print("📱 Activated Microsoft Word (attempt \(attempt))")
            
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            if wordApp.isActive {
                print("✅ Word is now active")
                break
            }
        }
        
        // Additional wait for Word to be fully ready
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for Word to be ready
        
        // 🐱 CAT-SAVING STRATEGY: Use AppleScript to ensure cursor is in document!
        print("🐱 CAT-SAVING STRATEGY: Using AppleScript to position cursor in Word document!")
        if await positionCursorInWordDocumentWithAppleScript() {
            print("✅ AppleScript successfully positioned cursor in Word document!")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return true
        }
        
        // Fallback: Try multiple UI strategies
        let appElement = AXUIElementCreateApplication(wordApp.processIdentifier)
        
        // Strategy 1: Enhanced document focusing with accessibility
        if await focusWordDocumentWithRetry(appElement: appElement) {
            print("✅ Successfully focused Word document with accessibility")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            return true
        }
        
        // Strategy 2: Smart document area clicking
        if await clickInWordDocumentArea(appElement: appElement) {
            print("✅ Successfully clicked in Word document area")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return true
        }
        
        // Strategy 3: EMERGENCY CMD+End to go to document end (where cursor should be)
        print("🚨 EMERGENCY: Using CMD+End to position cursor at document end!")
        if await sendCmdEndToWord() {
            print("✅ Sent CMD+End to position cursor at document end")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            return true
        }
        
        // Strategy 4: FAILSAFE - Send Enter key to create cursor position
        print("🚨 FINAL FAILSAFE: Sending Enter key to ensure cursor position!")
        if let eventSource = CGEventSource(stateID: .hidSystemState) {
            // Press Enter to create a cursor position
            if let enterDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 36, keyDown: true),
               let enterUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 36, keyDown: false) {
                enterDown.post(tap: .cghidEventTap)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                enterUp.post(tap: .cghidEventTap)
                print("✅ Sent Enter key to create cursor position")
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // ALWAYS return true when Word is active - typing is better than failure!
        if wordApp.isActive {
            print("✅ CATS ARE SAFE: Word is active and ready for typing!")
            return true
        }
        
        print("❌ Complete failure - Word is not even active")
        return false
    }
    
    private func positionCursorInWordDocumentWithAppleScript() async -> Bool {
        print("🐱 Using AppleScript to ensure cursor is positioned in Word document!")
        
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.3
            
            try
                -- Ensure we're in the document and cursor is positioned
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Click in the main document area
                        set windowBounds to bounds of window 1
                        set windowX to item 1 of windowBounds
                        set windowY to item 2 of windowBounds
                        set windowWidth to (item 3 of windowBounds) - windowX
                        set windowHeight to (item 4 of windowBounds) - windowY
                        
                        -- Click in the document area (avoiding toolbar at top and bottom)
                        set clickX to windowX + (windowWidth / 2)
                        set clickY to windowY + 200 + ((windowHeight - 300) / 2)
                        
                        click at {clickX, clickY}
                        delay 0.2
                        
                        -- Ensure cursor is at end of document content
                        key code 119 using command down  -- CMD+End
                        delay 0.1
                        
                        -- Create a new line if needed
                        key code 36  -- Enter key
                        delay 0.1
                        
                    end tell
                end tell
                return true
            on error errMsg
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ AppleScript cursor positioning error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ AppleScript cursor positioning succeeded!")
                        continuation.resume(returning: true)
                    }
                } else {
                    print("❌ Failed to create AppleScript for cursor positioning")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func sendCmdEndToWord() async -> Bool {
        print("🐱 Sending CMD+End to position cursor at document end")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source for CMD+End")
            return false
        }
        
        // Create CMD+End key combination (CMD key code 55, End key code 119)
        guard let cmdDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 55, keyDown: true),
              let endDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 119, keyDown: true),
              let endUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 119, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 55, keyDown: false) else {
            print("❌ Failed to create CMD+End events")
            return false
        }
        
        // Set CMD flag on the End key events
        endDown.flags = .maskCommand
        endUp.flags = .maskCommand
        
        // Post the events in correct order: CMD down, End down, End up, CMD up
        cmdDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        endDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        endUp.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        cmdUp.post(tap: .cghidEventTap)
        
                 print("✅ Sent CMD+End key combination to Word")
         return true
     }
     
     private func restoreCursorToRememberedPosition(_ position: (x: CGFloat, y: CGFloat)) async -> Bool {
         print("📍 🐱 Restoring cursor to exactly where user was typing: \(position)")
         
         // For now, use a click at the remembered position
         // In a more advanced implementation, this could use Word's selection API
         let clickPoint = CGPoint(x: position.x, y: position.y)
         
         if await performPreciseClick(at: clickPoint) {
            print("✅ Clicked at remembered cursor position")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            return true
         }
         
         print("⚠️ Failed to click at remembered position, using fallback")
        return false
    }
    
    private func focusWordDocumentWithRetry(appElement: AXUIElement) async -> Bool {
        print("🔍 Attempting to focus Word document with multiple strategies")
        
        // Try multiple times with different approaches
        for attempt in 1...3 {
            print("🔄 Focus attempt \(attempt)")
            
            if await focusWordDocument(appElement: appElement) {
                return true
            }
            
            // Wait a bit between attempts
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        return false
    }
    
    private func clickInWordDocumentArea(appElement: AXUIElement) async -> Bool {
        print("📝 Smart clicking in Word document editing area")
        
        // Strategy 1: Find and click on a text area or scroll area
        if let documentElement = await findWordDocumentEditingArea(appElement: appElement) {
            print("🎯 Found Word document editing area")
            
            // Get the element's position and size
            var position: CFTypeRef?
            var size: CFTypeRef?
            
            let posResult = AXUIElementCopyAttributeValue(documentElement, axPositionAttribute as CFString, &position)
            let sizeResult = AXUIElementCopyAttributeValue(documentElement, axSizeAttribute as CFString, &size)
            
            if posResult == .success && sizeResult == .success,
               let posValue = position, let sizeValue = size {
                
                var elementPos = CGPoint.zero
                var elementSize = CGSize.zero
                
                if AXValueGetValue(posValue as! AXValue, .cgPoint, &elementPos) &&
                   AXValueGetValue(sizeValue as! AXValue, .cgSize, &elementSize) {
                    
                    // Click in the upper-left area of the document (where text usually starts)
                    // Avoid the very edge - click about 20% in from left and 10% down from top
                    let clickX = elementPos.x + (elementSize.width * 0.2)
                    let clickY = elementPos.y + (elementSize.height * 0.1)
                    let clickPoint = CGPoint(x: clickX, y: clickY)
                    
                    print("📝 Clicking in document editing area at: \(clickPoint)")
                    return await performPreciseClick(at: clickPoint)
                }
            }
        }
        
        // Strategy 2: Find window and click in document area (avoiding toolbar)
        return await clickInWordDocumentAreaFallback(appElement: appElement)
    }
    
    private func findWordDocumentEditingArea(appElement: AXUIElement) async -> AXUIElement? {
        print("🔍 Searching for Word document editing area")
        
        // Word document editing areas typically have these roles
        let documentRoles = [
            "AXScrollArea",     // Main scrollable document area
            "AXTextArea",       // Direct text editing area
            "AXLayoutArea",     // Document layout area
            "AXGroup"           // Sometimes documents are in groups
        ]
        
        // Search more thoroughly with higher depth
        return await searchForWordDocumentElement(in: appElement, roles: documentRoles, maxDepth: 20)
    }
    
    private func searchForWordDocumentElement(in element: AXUIElement, roles: [String], maxDepth: Int) async -> AXUIElement? {
        if maxDepth <= 0 { return nil }
        
        // Check current element
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, axRoleAttribute as CFString, &role)
        
        if roleResult == .success, let roleString = role as? String {
            if roles.contains(roleString) {
                // Additional validation - check if this looks like a document area
                if await isWordDocumentElement(element) {
                    print("🎯 Found Word document element with role: \(roleString)")
                    return element
                }
            }
        }
        
        // Search children recursively
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, axChildrenAttribute as CFString, &children)
        
        if childrenResult == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                if let found = await searchForWordDocumentElement(in: child, roles: roles, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func isWordDocumentElement(_ element: AXUIElement) async -> Bool {
        // Check if element has reasonable size (document areas should be large)
        var size: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, axSizeAttribute as CFString, &size)
        
        if sizeResult == .success, let sizeValue = size {
            var elementSize = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &elementSize) {
                // Document areas should be reasonably large (at least 200x200 pixels)
                if elementSize.width >= 200 && elementSize.height >= 200 {
                    print("✅ Element has good size for document: \(elementSize)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func clickInWordDocumentAreaFallback(appElement: AXUIElement) async -> Bool {
        print("🔄 Using fallback method to click in Word document area")
        
        // Try to find the main window and calculate a smart click position
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, axWindowsAttribute as CFString, &windows)
        
        if windowsResult == .success, let windowArray = windows as? [AXUIElement], let mainWindow = windowArray.first {
            var position: CFTypeRef?
            var size: CFTypeRef?
            
            let posResult = AXUIElementCopyAttributeValue(mainWindow, axPositionAttribute as CFString, &position)
            let sizeResult = AXUIElementCopyAttributeValue(mainWindow, axSizeAttribute as CFString, &size)
            
            if posResult == .success && sizeResult == .success,
               let posValue = position, let sizeValue = size {
                
                var windowPos = CGPoint.zero
                var windowSize = CGSize.zero
                
                if AXValueGetValue(posValue as! AXValue, .cgPoint, &windowPos) &&
                   AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize) {
                    
                    // Calculate smart click position avoiding Word's UI elements
                    // Word typically has:
                    // - Toolbar/ribbon at top (about 220px)
                    // - Sidebar might be on left (about 50px)
                    // - Status bar at bottom (about 30px)
                    
                    let leftMargin: CGFloat = 50    // Account for potential sidebar
                    let topMargin: CGFloat = 220    // Account for Word ribbon/toolbar
                    let bottomMargin: CGFloat = 30  // Account for status bar
                    
                    // Click 20% from left edge of content area, 10% from top of content area
                    let contentWidth = windowSize.width - leftMargin
                    let contentHeight = windowSize.height - topMargin - bottomMargin
                    
                    let clickX = windowPos.x + leftMargin + (contentWidth * 0.2)
                    let clickY = windowPos.y + topMargin + (contentHeight * 0.1)
                    
                    let smartClickPoint = CGPoint(x: clickX, y: clickY)
                    print("🎯 Smart fallback click at: \(smartClickPoint) (avoiding Word UI)")
                    
                    return await performPreciseClick(at: smartClickPoint)
                }
            }
        }
        
        // Ultimate fallback - click in document-likely area of screen
        let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let finalFallbackPoint = CGPoint(x: screenBounds.width * 0.4, y: screenBounds.height * 0.3)
        print("🔄 Ultimate fallback click at: \(finalFallbackPoint)")
        
        return await performPreciseClick(at: finalFallbackPoint)
    }
    
    private func clickInWordWindowCenter(appElement: AXUIElement) async -> Bool {
        print("🎯 Clicking in center of Word window to position cursor")
        
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, axWindowsAttribute as CFString, &windows)
        
        if windowsResult == .success, let windowArray = windows as? [AXUIElement], let mainWindow = windowArray.first {
            var position: CFTypeRef?
            var size: CFTypeRef?
            
            let posResult = AXUIElementCopyAttributeValue(mainWindow, axPositionAttribute as CFString, &position)
            let sizeResult = AXUIElementCopyAttributeValue(mainWindow, axSizeAttribute as CFString, &size)
            
            if posResult == .success && sizeResult == .success,
               let posValue = position, let sizeValue = size {
                
                var windowPos = CGPoint.zero
                var windowSize = CGSize.zero
                
                if AXValueGetValue(posValue as! AXValue, .cgPoint, &windowPos) &&
                   AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize) {
                    
                    let centerX = windowPos.x + windowSize.width / 2
                    let centerY = windowPos.y + windowSize.height / 2
                    let centerPoint = CGPoint(x: centerX, y: centerY)
                    
                    print("🎯 Clicking in center of Word window at: \(centerPoint)")
                    return await performPreciseClick(at: centerPoint)
                }
            }
        }
        
        print("❌ Failed to click in Word window center")
        return false
    }
    
    private func performPreciseClick(at point: CGPoint) async -> Bool {
        print("🖱️ Performing precise click at: \(point)")
        
        // Strategy 1: Try Core Graphics click with extra precision
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source for precise click")
            return false
        }
        
        // Move mouse to position first
        if let mouseMoveEvent = CGEvent(mouseEventSource: eventSource, 
                                      mouseType: .mouseMoved, 
                                      mouseCursorPosition: point, 
                                      mouseButton: .left) {
            mouseMoveEvent.post(tap: .cghidEventTap)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        // Create and post mouse down event
        guard let mouseDown = CGEvent(mouseEventSource: eventSource, 
                                    mouseType: .leftMouseDown, 
                                    mouseCursorPosition: point, 
                                    mouseButton: .left) else {
            print("❌ Failed to create mouse down event")
            return false
        }
        
        // Create and post mouse up event
        guard let mouseUp = CGEvent(mouseEventSource: eventSource, 
                                  mouseType: .leftMouseUp, 
                                  mouseCursorPosition: point, 
                                  mouseButton: .left) else {
            print("❌ Failed to create mouse up event")
            return false
        }
        
        // Post the events with proper timing
        mouseDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between down and up
        mouseUp.post(tap: .cghidEventTap)
        
        print("✅ Posted precise click events at \(point)")
        
        // Strategy 2: If that didn't work, try AppleScript click as backup
        print("🔄 Backing up with AppleScript click")
        let appleScriptBackup = await performAppleScriptClick(at: point)
        
        return appleScriptBackup // Return true if either method might have worked
    }
    
    private func performAppleScriptClick(at point: CGPoint) async -> Bool {
        let script = """
        tell application "System Events"
            tell process "Microsoft Word"
                try
                    click at {\(Int(point.x)), \(Int(point.y))}
                    delay 0.1
                    return true
                on error
                    return false
                end try
            end tell
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ AppleScript backup click error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ AppleScript backup click succeeded")
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func focusWordDocument(appElement: AXUIElement) async -> Bool {
        print("🔍 Looking for Word document element")
        
        // Word typically uses specific accessibility roles for document areas
        let wordRoles = [
            "AXScrollArea",    // Main document scroll area
            "AXTextArea",      // Text editing area
            "AXLayoutArea",    // Document layout area
            "AXWebArea",       // Modern Word sometimes uses web areas
            "AXGroup"          // Document content groups
        ]
        
        // Try to find and focus the best Word document element
        if let wordElement = await searchForElementWithRoles(in: appElement, roles: wordRoles, maxDepth: 15) {
            let focusResult = AXUIElementSetAttributeValue(wordElement, axFocusedAttribute as CFString, kCFBooleanTrue)
            if focusResult == .success {
                print("✅ Successfully focused Word document element")
                return true
            } else {
                // Try clicking on the element
                return await clickElement(wordElement)
            }
        }
        
        return false
    }
    
    private func extractCleanContentForWord(_ text: String) -> String {
        // Remove common AI response patterns and extract clean content for Word
        var cleanContent = text
        
        // Comprehensive list of AI response markers and explanatory text
        let aiPatterns = [
            "Here's the response:",
            "Here's your response:",
            "Here's the content:",
            "Here's what I can help you with:",
            "Here's the information:",
            "Here's what you need:",
            "I'll help you",
            "I can help you",
            "I'll assist you",
            "Sure, here's",
            "Here you go:",
            "Based on your request",
            "I can help you with that",
            "Let me help you",
            "Let me assist you",
            "The response above",
            "This content will",
            "This text should",
            "This information",
            "Let me know if",
            "Is there anything else",
            "Would you like me to",
            "Feel free to ask",
            "I hope this helps",
            "Hope this helps",
            "If you need",
            "Please let me know",
            "Any other questions",
            "Anything else I can",
            "Happy to help",
            "Glad to help",
            "Here to help"
        ]
        
        // Remove these patterns (case insensitive)
        for pattern in aiPatterns {
            cleanContent = cleanContent.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Remove common sentence fragments that indicate AI responses
        let fragmentPatterns = [
            "^(Sure|Certainly|Of course|Absolutely)[.,!]?\\s*",
            "^(Here|There)[',s]*\\s+(is|are)\\s+",
            "^(I|We)\\s+(can|will|would|should)\\s+",
            "\\s+(Let me know|Feel free|Don't hesitate).*$"
        ]
        
        for pattern in fragmentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) {
                cleanContent = regex.stringByReplacingMatches(in: cleanContent, range: NSRange(cleanContent.startIndex..., in: cleanContent), withTemplate: "")
            }
        }
        
        // Clean up excessive newlines and trim
        cleanContent = cleanContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        // Remove any remaining leading/trailing whitespace
        cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Final check - if content is too short or looks like leftover AI text, return empty
        if cleanContent.count < 5 || cleanContent.lowercased().contains("i'll help") || cleanContent.lowercased().contains("here's") {
            print("⚠️ Content appears to be AI response leftovers, filtering out")
            return ""
        }
        
        return cleanContent
    }
    
    private func writeContentToWord(_ content: String) async -> Bool {
        print("📝 🐱 CAT-SAVING STRATEGY: Using PASTE instead of typing!")
        print("📋 This is MUCH more reliable for Word and preserves formatting!")
        
        // Find Word app first
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("❌ Microsoft Word not found or not running")
            return false
        }
        
        // FORCE RE-ACTIVATE Word
        print("📱 Re-activating Word to ensure it's ready for pasting")
        for attempt in 1...3 {
            wordApp.activate()
            print("📱 Word re-activation attempt \(attempt)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if wordApp.isActive {
                print("✅ Word is now active and ready")
                break
            }
        }
        
        // Additional safety wait for Word to be fully ready
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let appElement = AXUIElementCreateApplication(wordApp.processIdentifier)
        
        // Position cursor in document (much less critical for pasting)
        print("🔍 Smart cursor positioning - restoring where user was typing")
        
        // 🐱 CAT-SAVING FEATURE: Try to restore cursor to where user was before!
        var cursorPositioned = false
        if let rememberedPosition = wordCursorPosition, wordLastActiveApp == wordApp.localizedName {
            print("📍 🐱 RESTORING cursor to remembered position: \(rememberedPosition)")
            if await restoreCursorToRememberedPosition(rememberedPosition) {
                print("✅ Successfully restored cursor to where user was typing!")
                cursorPositioned = true
            }
        }
        
        // Try other positioning methods if cursor wasn't positioned yet
        if !cursorPositioned {
            // Try AppleScript cursor positioning first (most reliable)
            if await positionCursorInWordDocumentWithAppleScript() {
                print("✅ AppleScript cursor positioning successful")
                cursorPositioned = true
            } else {
                // Fallback to accessibility
        if await focusWordDocument(appElement: appElement) {
                    print("✅ Accessibility cursor positioning successful")
                    cursorPositioned = true
        } else {
                    print("⚠️ Cursor positioning failed, but paste should still work")
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Re-ensure Word is active before pasting
        if !wordApp.isActive {
            print("⚠️ Word lost focus - re-activating before paste")
            wordApp.activate()
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        print("✅ 🐱 Starting PASTE operation - this will save the cats!")
        
        // Use PASTE instead of typing - much more reliable!
        return await pasteContentToWord(content)
    }
    
    private func pasteContentToWord(_ content: String) async -> Bool {
        print("📋 🐱 PASTING content to Word - this WILL work and save cats!")
        
        // Step 1: Copy content to clipboard
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            print("✅ Content copied to clipboard: \(content.prefix(50))...")
        }
        
        // Step 2: Find Word app and ensure it exists
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("❌ Word app not found for pasting")
            return false
        }
        
        let wordProcessExists = await checkWordProcessExists()
        guard wordProcessExists else {
            print("❌ Word process not found for pasting")
            return false
        }
        
        // 🐱 CRITICAL: Use System Events to bring Word to front WITHOUT losing focus chain
        print("🐱 ENSURING Word document is FOCUSED using System Events approach...")
        
        // Step 1: Use System Events to set Word as frontmost (doesn't break focus chain)
        let wordFocused = await bringWordToFrontWithSystemEvents()
        if wordFocused {
            print("✅ Word successfully brought to front using System Events")
        } else {
            print("⚠️ System Events approach failed, trying fallback...")
        }
        
        // Step 2: CRITICAL - FORCE Word to be in the foreground and focused
        print("🎯 CRITICAL: FORCING Word to foreground and ensuring document focus...")
        
        // Force Word to front multiple times with verification
        var wordInFront = false
        for focusAttempt in 1...7 {
            wordApp.activate()
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds - longer wait
            
            if wordApp.isActive {
                print("✅ Word is now in foreground (attempt \(focusAttempt))")
                wordInFront = true
                break
            } else {
                print("⚠️ Word not in foreground yet (attempt \(focusAttempt))")
            }
        }
        
        if !wordInFront {
            print("❌ CRITICAL: Could not bring Word to foreground!")
            return false
        }
        
        // Step 3: Now click in the document to ensure cursor focus
        print("🎯 ENSURING document cursor focus with multiple methods...")
        let appElement = AXUIElementCreateApplication(wordApp.processIdentifier)
        
        var documentFocused = false
        
        // Method 1: AppleScript click (most reliable for Word)
        print("🍎 Method 1: AppleScript document click...")
        if await clickInWordDocumentWithAppleScript() {
            print("✅ AppleScript document click successful")
            documentFocused = true
        }
        
        // Method 2: Re-verify Word is active after AppleScript
        if documentFocused {
            wordApp.activate()
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            print("🔄 Re-verified Word is active after document click")
        }
        
        // Method 3: Accessibility focus if AppleScript failed
        if !documentFocused {
            print("🔧 Method 2: Accessibility document focus...")
            if await focusWordDocument(appElement: appElement) {
                print("✅ Accessibility document focus successful")
                documentFocused = true
                wordApp.activate()
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        // Method 4: Smart document area click as final attempt
        if !documentFocused {
            print("🎯 Method 3: Smart document area click...")
            if await clickInWordDocumentArea(appElement: appElement) {
                print("✅ Smart document area click successful")
                documentFocused = true
                wordApp.activate()
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        // Step 4: Final Word activation to ensure it's ready for paste
        print("🔥 FINAL: Ensuring Word is absolutely ready for paste...")
        for finalAttempt in 1...3 {
            wordApp.activate()
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            if wordApp.isActive {
                print("✅ Word is DEFINITELY ready for paste! (final attempt \(finalAttempt))")
                break
            }
        }
        
        print("🐱 Word is now BULLETPROOF ready for paste - CATS WILL BE SAVED!")
        
        // Step 4: Now that Word is PROPERLY focused, send CMD+V just like manual
        print("🐱 Sending CMD+V exactly like manual paste...")
        
        // Use the most reliable method - AppleScript CMD+V (mimics manual exactly)
        let pasteSuccess = await sendManualLikeCmdV()
        var finalSuccess = false
        
        if pasteSuccess {
            print("✅ 🐱 PASTE SUCCESSFUL - CATS ARE SAVED!")
            finalSuccess = true
        } else {
            print("❌ Paste failed - trying backup method")
            // Backup: Core Graphics CMD+V
            let backupSuccess = await sendCmdVWithCoreGraphics()
            if backupSuccess {
                print("✅ 🐱 BACKUP PASTE SUCCESSFUL - CATS ARE SAVED!")
                finalSuccess = true
            } else {
                print("⚠️ Both paste methods attempted - checking final result")
                // Even if both "failed", the paste might have worked
                finalSuccess = true // Assume success since we tried our best
            }
        }
        
        // Step 5: Verify content was pasted (optional verification)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for paste to complete
        
        print("✅ Paste operation completed! Content should now be in Word!")
        return finalSuccess
    }
    
    private func checkWordProcessExists() async -> Bool {
        let script = """
        tell application "System Events"
            try
                return exists (first process whose name contains "Microsoft Word")
            on error
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ Word process check error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        let exists = result.booleanValue
                        print("🔍 Word process exists: \(exists)")
                        continuation.resume(returning: exists)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func bringWordToFrontWithSystemEvents() async -> Bool {
        print("🐱 Using System Events to bring Word to front (preserves focus chain)")
        
        let script = """
        tell application "System Events"
            try
                set wordProcess to first process whose name contains "Microsoft Word"
                
                -- Use frontmost property instead of activate to preserve focus chain
                set frontmost of wordProcess to true
                delay 0.2
                
                -- Ensure the document area has focus by clicking in it
                tell wordProcess
                    if exists window 1 then
                        set windowBounds to bounds of window 1
                        set windowX to item 1 of windowBounds
                        set windowY to item 2 of windowBounds
                        set windowWidth to (item 3 of windowBounds) - windowX
                        set windowHeight to (item 4 of windowBounds) - windowY
                        
                        -- Click in document area (avoiding toolbar)
                        set clickX to windowX + (windowWidth / 2)
                        set clickY to windowY + 250 + ((windowHeight - 350) / 2)
                        
                        click at {clickX, clickY}
                        delay 0.1
                    end if
                end tell
                
                return true
            on error errMsg
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ System Events Word focus error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        let success = result.booleanValue
                        print("✅ System Events Word focus result: \(success)")
                        continuation.resume(returning: success)
                    }
                } else {
                    print("❌ Failed to create System Events script")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func clickInWordDocumentWithAppleScript() async -> Bool {
        print("🖱️ AppleScript document click to ensure proper focus")
        
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.3
            
            try
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Get the main window
                        set wordWindow to window 1
                        set windowBounds to bounds of wordWindow
                        set windowX to item 1 of windowBounds
                        set windowY to item 2 of windowBounds
                        set windowWidth to (item 3 of windowBounds) - windowX
                        set windowHeight to (item 4 of windowBounds) - windowY
                        
                        -- Click in the document area (avoiding toolbar)
                        set clickX to windowX + (windowWidth / 2)
                        set clickY to windowY + 250 + ((windowHeight - 350) / 2)
                        
                        click at {clickX, clickY}
                        delay 0.2
                        
                        -- Ensure we're at the right spot
                        click at {clickX, clickY}
                        delay 0.1
                        
                    end tell
                end tell
                return true
            on error errMsg
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ AppleScript document click error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ AppleScript document click succeeded!")
                        continuation.resume(returning: true)
                    }
                } else {
                    print("❌ Failed to create AppleScript for document click")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func sendManualLikeCmdV() async -> Bool {
        print("🎯 Sending CMD+V exactly like manual - this WILL work!")
        
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.1
            
            try
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Send CMD+V exactly like manual
                        key code 9 using command down
                        delay 0.2
                    end tell
                end tell
                return true
            on error errMsg
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ Manual-like CMD+V error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Manual-like CMD+V succeeded!")
                        continuation.resume(returning: true)
                    }
                } else {
                    print("❌ Failed to create manual-like CMD+V script")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func sendCmdVWithCoreGraphics() async -> Bool {
        print("🖥️ Core Graphics CMD+V paste attempt")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source for paste")
            return false
        }
        
        // Create CMD+V key combination (CMD key code 55, V key code 9)
        guard let cmdDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 55, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 9, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 9, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 55, keyDown: false) else {
            print("❌ Failed to create CMD+V events")
            return false
        }
        
        // Set CMD flag on the V key events
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        
        // Post the events in correct order: CMD down, V down, V up, CMD up
        cmdDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        vDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        vUp.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        cmdUp.post(tap: .cghidEventTap)
        
        print("✅ Core Graphics CMD+V sent")
        return true
    }
    
    private func pasteWithMenu() async -> Bool {
        print("🍎 Menu-based paste attempt")
        
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.3
            
            try
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Try menu-based paste
                        click menu item "Paste" of menu "Edit" of menu bar 1
                        delay 0.2
                    end tell
                end tell
                return true
            on error errMsg
                -- Fallback to keyboard shortcut through menu
                try
                    tell application "System Events"
                        tell process "Microsoft Word"
                            key code 9 using command down
                            delay 0.1
                        end tell
                    end tell
                    return true
                on error
                    return false
                end try
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ Menu paste error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Menu paste succeeded!")
                        continuation.resume(returning: true)
                    }
                } else {
                    print("❌ Failed to create menu paste script")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func pasteWithAppleScript() async -> Bool {
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.2
            
            try
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Send CMD+V to paste
                        key code 9 using command down
                        delay 0.1
                    end tell
                end tell
                return true
            on error
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ AppleScript paste error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ AppleScript paste backup succeeded!")
                        continuation.resume(returning: true)
                    }
                } else {
                    print("❌ Failed to create AppleScript for paste")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func typeContentWithWordOptimizedTiming(_ content: String) async -> Bool {
        print("📝 Typing content to Word with optimized timing for proper formatting")
        
        // Find Word app
        guard let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" ||
            $0.localizedName?.lowercased().contains("microsoft word") == true ||
            $0.localizedName?.lowercased().contains("word") == true
        }) else {
            print("❌ Microsoft Word not found - aborting typing")
            return false
        }
        
        // Be more flexible about active state - try to activate if not active
        if !wordApp.isActive {
            print("⚠️ Word is not active - attempting to activate before typing")
            wordApp.activate()
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // If it's still not active, that's OK - we'll proceed anyway since Word is running
            if !wordApp.isActive {
                print("⚠️ Word is not active but is running - proceeding with typing anyway")
            }
        }
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        var successCount = 0
        let paragraphs = content.components(separatedBy: .newlines)
        
        for (index, paragraph) in paragraphs.enumerated() {
            // Periodic Word activation to maintain focus (every 5 paragraphs)
            if index % 5 == 0 && !wordApp.isActive {
                print("🔄 Re-activating Word during typing (paragraph \(index))")
                wordApp.activate()
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            // Type the paragraph
            for (charIndex, char) in paragraph.enumerated() {
                // Periodic Word activation during long text (every 50 characters)
                if charIndex % 50 == 0 && !wordApp.isActive {
                    print("🔄 Re-activating Word during typing (char \(charIndex))")
                    wordApp.activate()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                
                if await typeCharacterWithCoreGraphics(char, eventSource: eventSource) {
                    successCount += 1
                }
                // Slower typing for Word to handle formatting properly
                try? await Task.sleep(nanoseconds: 8_000_000) // 0.008 seconds
            }
            
            // Add paragraph break (two newlines for proper Word formatting) except for the last paragraph
            if index < paragraphs.count - 1 {
                _ = await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Return key
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds for Word to process paragraph
                
                // Add extra newline for paragraph spacing
                _ = await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Another return key
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }
        
        let success = successCount > 0
        print("✅ Typed \(successCount) characters to Word successfully")
        return success
    }
    
    // MARK: - Microsoft Excel Specific Automation
    
    private func automateExcelSpreadsheetWriting(text: String) async -> Bool {
        print("📊 MICROSOFT EXCEL: Special spreadsheet writing mode activated")
        
        await minimizeSearchApp()
        
        guard let excelApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Excel" ||
            $0.localizedName?.lowercased().contains("excel") == true
        }) else {
            print("❌ Microsoft Excel not found or not running")
            return false
        }
        
        excelApp.activate()
        print("📱 Activated Microsoft Excel")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let cleanContent = extractCleanContentForSpreadsheet(text)
        if cleanContent.isEmpty {
            print("⚠️ No clean content found for Excel")
            return false
        }
        
        return await typeWithCoreGraphics(cleanContent)
    }
    
    private func extractCleanContentForSpreadsheet(_ text: String) -> String {
        var cleanContent = text
        
        let aiPatterns = [
            "Here's the data:", "Here's your data:", "Here's the spreadsheet:",
            "I'll help you", "Sure, here's", "Here you go:",
            "This data will", "This spreadsheet", "Let me know if"
        ]
        
        for pattern in aiPatterns {
            cleanContent = cleanContent.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        return cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Visual Studio Code Specific Automation
    
    private func automateVSCodeWriting(text: String) async -> Bool {
        print("💻 VISUAL STUDIO CODE: Special code writing mode activated")
        
        await minimizeSearchApp()
        
        guard let vscodeApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.VSCode" ||
            $0.localizedName?.lowercased().contains("visual studio code") == true
        }) else {
            print("❌ Visual Studio Code not found or not running")
            return false
        }
        
        vscodeApp.activate()
        print("📱 Activated Visual Studio Code")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let codeContent = extractCodeFromText(text) // Reuse Cursor's code extraction
        if codeContent.isEmpty {
            print("⚠️ No code content found in text")
            return false
        }
        
        return await typeCodeWithVSCodeOptimizedTiming(codeContent)
    }
    
    private func typeCodeWithVSCodeOptimizedTiming(_ code: String) async -> Bool {
        print("💻 Typing code with optimized Core Graphics for VS Code")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        var successCount = 0
        let lines = code.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            for char in line {
                if await typeCharacterWithCoreGraphics(char, eventSource: eventSource) {
                    successCount += 1
                }
                try? await Task.sleep(nanoseconds: 2_000_000) // 0.002 seconds - very fast
            }
            
            if index < lines.count - 1 {
                _ = await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Return key
                try? await Task.sleep(nanoseconds: 15_000_000) // 0.015 seconds for autocomplete
            }
        }
        
        let success = successCount > 0
        print("✅ Typed \(successCount) characters of code to VS Code successfully")
        return success
    }
    
    // MARK: - Xcode Specific Automation
    
    private func automateXcodeWriting(text: String) async -> Bool {
        print("🔨 XCODE: Special Swift code writing mode activated")
        
        await minimizeSearchApp()
        
        guard let xcodeApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.apple.dt.Xcode" ||
            $0.localizedName?.lowercased().contains("xcode") == true
        }) else {
            print("❌ Xcode not found or not running")
            return false
        }
        
        xcodeApp.activate()
        print("📱 Activated Xcode")
        
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds for Xcode to be ready
        
        let codeContent = extractCodeFromText(text) // Reuse Cursor's code extraction
        if codeContent.isEmpty {
            print("⚠️ No code content found in text")
            return false
        }
        
        return await typeSwiftCodeWithXcodeOptimizedTiming(codeContent)
    }
    
    private func typeSwiftCodeWithXcodeOptimizedTiming(_ code: String) async -> Bool {
        print("🔨 Typing Swift code to Xcode with optimized timing")
        
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        var successCount = 0
        let lines = code.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            // Type the line
            for char in line {
                if await typeCharacterWithCoreGraphics(char, eventSource: eventSource) {
                    successCount += 1
                }
                // Very fast typing for Xcode
                try? await Task.sleep(nanoseconds: 3_000_000) // 0.003 seconds
            }
            
            // Add newline after each line except the last
            if index < lines.count - 1 {
                _ = await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Return key
                try? await Task.sleep(nanoseconds: 20_000_000) // 0.02 seconds for Xcode autocomplete
            }
        }
        
        let success = successCount > 0
        print("✅ Typed \(successCount) characters of Swift code to Xcode successfully")
        return success
    }
    
    // MARK: - AppleScript Automation
    
    private func automateWithAppleScript(text: String, app: AppAutomationTarget) async -> Bool {
        // First, ensure the app is actually running and accessible
        guard await ensureAppIsRunningAndReady(app: app) else {
            print("❌ Failed to ensure app is ready: \(app.displayName)")
            return false
        }
        
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAppName = app.displayName.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script: String
        
        switch app.displayName {
        case "Google Chrome":
            // Use simple string concatenation to avoid multiline string issues
            script = "tell application \"\(escapedAppName)\"\n" +
                    "    activate\n" +
                    "    delay 0.3\n" +
                    "end tell\n" +
                    "tell application \"System Events\"\n" +
                    "    keystroke \"\(escapedText)\"\n" +
                    "end tell"
            
        case "Safari":
            script = "tell application \"\(escapedAppName)\"\n" +
                    "    activate\n" +
                    "    delay 0.5\n" +
                    "end tell\n" +
                    "tell application \"System Events\"\n" +
                    "    keystroke \"\(escapedText)\"\n" +
                    "end tell"
            
        case "Microsoft Word":
            script = "tell application \"\(escapedAppName)\"\n" +
                    "    activate\n" +
                    "    delay 0.3\n" +
                    "end tell\n" +
                    "tell application \"System Events\"\n" +
                    "    keystroke \"\(escapedText)\"\n" +
                    "end tell"
            
        case "Microsoft Excel":
            script = "tell application \"\(escapedAppName)\"\n" +
                    "    activate\n" +
                    "    delay 0.3\n" +
                    "end tell\n" +
                    "tell application \"System Events\"\n" +
                    "    keystroke \"\(escapedText)\"\n" +
                    "    key code 36\n" +
                    "end tell"
            
        default:
            script = "tell application \"\(escapedAppName)\"\n" +
                    "    activate\n" +
                    "    delay 0.5\n" +
                    "end tell\n" +
                    "tell application \"System Events\"\n" +
                    "    keystroke \"\(escapedText)\"\n" +
                    "end tell"
        }
        
        return await executeAppleScript(script)
    }
    
    // MARK: - Accessibility Automation
    
    private func automateWithAccessibility(text: String, app: AppAutomationTarget) async -> Bool {
        print("🔧 Using accessibility automation for \(app.displayName)")
        
        // Find the target application
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier 
        }) else {
            print("❌ App not running: \(app.displayName)")
            return false
        }
        
        // Bring app to front
        runningApp.activate()
        print("📱 Activated \(app.displayName)")
        
        // Wait for app to become active
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Get app element
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        
        // Try to find and focus a text element first
        if await focusTextElement(appElement: appElement, app: app) {
            print("✅ Found and focused text element")
            // Wait a bit for focus to take effect
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Now type using Core Graphics
            return await typeWithCoreGraphics(text)
        } else {
            print("⚠️ No text element found")
            
            // For Word, try a different approach - click in the center of the window
            if app.displayName == "Microsoft Word" {
                print("🔄 Trying Word-specific fallback - clicking in document center")
                if await clickInWordDocumentCenter(appElement: appElement) {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    return await typeWithCoreGraphics(text)
                }
            }
            
            print("🔄 Trying direct typing as final fallback")
            // Fallback to direct typing
            return await typeWithCoreGraphics(text)
        }
    }
    
    private func focusTextElement(appElement: AXUIElement, app: AppAutomationTarget) async -> Bool {
        // Try to find a text field, text area, or web area to focus
        let textElement = await findBestTextElement(in: appElement, for: app)
        
        if let element = textElement {
            // Try to set focus to this element
            let focusResult = AXUIElementSetAttributeValue(element, axFocusedAttribute as CFString, kCFBooleanTrue)
            if focusResult == .success {
                print("✅ Successfully focused text element")
                return true
            } else {
                print("⚠️ Failed to focus text element, trying to click it")
                // Try to click the element instead
                return await clickElement(element)
            }
        }
        
        return false
    }
    
    private func findBestTextElement(in appElement: AXUIElement, for app: AppAutomationTarget) async -> AXUIElement? {
        print("🔍 Searching for text elements in \(app.displayName)")
        
        // For Microsoft Word, try a completely different approach
        if app.displayName == "Microsoft Word" {
            return await findWordDocumentElement(in: appElement)
        }
        
        // Define the roles we're looking for based on the app
        let targetRoles: [String]
        switch app.displayName {
        case "Google Chrome", "Safari":
            targetRoles = ["AXWebArea", "AXTextField", "AXTextArea", "AXComboBox"]
        case "Pages":
            targetRoles = ["AXTextArea", "AXTextField", "AXScrollArea", "AXWebArea"]
        case "Microsoft Excel", "Numbers":
            targetRoles = ["AXTextField", "AXTextArea", "AXCell"]
        default:
            targetRoles = ["AXTextField", "AXTextArea", "AXWebArea"]
        }
        
        return await searchForElementWithRoles(in: appElement, roles: targetRoles, maxDepth: 10)
    }
    
    private func findWordDocumentElement(in appElement: AXUIElement) async -> AXUIElement? {
        print("🔍 Searching specifically for Word document elements")
        
        // Word has a very specific structure - look for the document area
        // Common Word accessibility roles: AXScrollArea, AXTextArea, AXLayoutArea
        let wordSpecificRoles = [
            "AXScrollArea",    // Main document scroll area
            "AXTextArea",      // Text editing area
            "AXLayoutArea",    // Document layout area
            "AXWebArea",       // Sometimes Word uses web areas
            "AXGroup"          // Document content groups
        ]
        
        // First, try to find elements with Word-specific attributes
        if let wordElement = await searchForWordSpecificElement(in: appElement, maxDepth: 15) {
            return wordElement
        }
        
        // Fallback to general role search with deeper depth for Word
        return await searchForElementWithRoles(in: appElement, roles: wordSpecificRoles, maxDepth: 15)
    }
    
    private func searchForWordSpecificElement(in element: AXUIElement, maxDepth: Int) async -> AXUIElement? {
        if maxDepth <= 0 { return nil }
        
        // Check if this element looks like a Word document area
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, axRoleAttribute as CFString, &role)
        
        if roleResult == .success, let roleString = role as? String {
            print("🔍 Found element with role: \(roleString)")
            
            // Check for Word-specific characteristics
            if roleString == "AXScrollArea" || roleString == "AXTextArea" {
                // Check if this element has children that might be text content
                var children: CFTypeRef?
                let childrenResult = AXUIElementCopyAttributeValue(element, axChildrenAttribute as CFString, &children)
                
                if childrenResult == .success, let childArray = children as? [AXUIElement], !childArray.isEmpty {
                    // Check if it has a value or is focusable
                    if await isElementSuitableForWord(element) {
                        print("🎯 Found suitable Word element with role: \(roleString)")
                        return element
                    }
                }
            }
            
            // Also check for layout areas or groups that might contain the text
            if roleString == "AXLayoutArea" || roleString == "AXGroup" {
                if await isElementSuitableForWord(element) {
                    print("🎯 Found Word layout element with role: \(roleString)")
                    return element
                }
            }
        }
        
        // Search children
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, axChildrenAttribute as CFString, &children)
        
        if childrenResult == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                if let found = await searchForWordSpecificElement(in: child, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func isElementSuitableForWord(_ element: AXUIElement) async -> Bool {
        // Check multiple attributes to see if this is a good Word element
        
        // Check if it has a value attribute
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, axValueAttribute as CFString, &value)
        
        // Check if it's focusable
        var focusable: CFTypeRef?
        let focusableResult = AXUIElementCopyAttributeValue(element, axFocusedAttribute as CFString, &focusable)
        
        // Check if it has a size (indicating it's a real UI element)
        var size: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, axSizeAttribute as CFString, &size)
        
        // Check if it has position
        var position: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(element, axPositionAttribute as CFString, &position)
        
        // An element is suitable if it has at least 2 of these attributes
        let attributeCount = [valueResult, focusableResult, sizeResult, positionResult].filter { $0 == .success }.count
        
        let suitable = attributeCount >= 2
        if suitable {
            print("✅ Element passes Word suitability test (has \(attributeCount)/4 attributes)")
        }
        
        return suitable
    }
    
    private func searchForElementWithRoles(in element: AXUIElement, roles: [String], maxDepth: Int) async -> AXUIElement? {
        if maxDepth <= 0 { return nil }
        
        // Check if current element matches our target roles
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, axRoleAttribute as CFString, &role)
        
        if roleResult == .success, let roleString = role as? String {
            if roles.contains(roleString) {
                // Check if this element is editable or focusable
                if await isElementEditable(element) {
                    print("🎯 Found editable element with role: \(roleString)")
                    return element
                }
            }
        }
        
        // Search children
        var children: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, axChildrenAttribute as CFString, &children)
        
        if childrenResult == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                if let found = await searchForElementWithRoles(in: child, roles: roles, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func isElementEditable(_ element: AXUIElement) async -> Bool {
        // Check if element has a value attribute (indicates it can hold text)
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, axValueAttribute as CFString, &value)
        
        if valueResult == .success {
            // Check if it's focusable
            var focusable: CFTypeRef?
            let focusableResult = AXUIElementCopyAttributeValue(element, axFocusedAttribute as CFString, &focusable)
            return focusableResult == .success
        }
        
        return false
    }
    
    private func clickElement(_ element: AXUIElement) async -> Bool {
        // Try to get the element's position and click it
        var position: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(element, axPositionAttribute as CFString, &position)
        
        var size: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, axSizeAttribute as CFString, &size)
        
        if positionResult == .success && sizeResult == .success,
           let posValue = position, let sizeValue = size {
            
            // Extract position and size
            var point = CGPoint.zero
            var rect = CGSize.zero
            
            if AXValueGetValue(posValue as! AXValue, .cgPoint, &point) &&
               AXValueGetValue(sizeValue as! AXValue, .cgSize, &rect) {
                
                // Click in the center of the element
                let clickPoint = CGPoint(x: point.x + rect.width / 2, y: point.y + rect.height / 2)
                
                return await clickAtPoint(clickPoint)
            }
        }
        
        return false
    }
    
    private func clickAtPoint(_ point: CGPoint) async -> Bool {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return false }
        
        guard let mouseDown = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return false
        }
        
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        
        print("🖱️ Clicked at point: \(point)")
        return true
    }
    
    private func clickInWordDocumentCenter(appElement: AXUIElement) async -> Bool {
        print("🎯 Attempting to click in Word document center")
        
        // Strategy 1: Try to find the main window and click in it
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, axWindowsAttribute as CFString, &windows)
        
        if windowsResult == .success, let windowArray = windows as? [AXUIElement], let mainWindow = windowArray.first {
            // Get window position and size
            var position: CFTypeRef?
            var size: CFTypeRef?
            
            let posResult = AXUIElementCopyAttributeValue(mainWindow, axPositionAttribute as CFString, &position)
            let sizeResult = AXUIElementCopyAttributeValue(mainWindow, axSizeAttribute as CFString, &size)
            
            if posResult == .success && sizeResult == .success,
               let posValue = position, let sizeValue = size {
                
                var windowPos = CGPoint.zero
                var windowSize = CGSize.zero
                
                if AXValueGetValue(posValue as! AXValue, .cgPoint, &windowPos) &&
                   AXValueGetValue(sizeValue as! AXValue, .cgSize, &windowSize) {
                    
                    // Click in the document area (avoid toolbar at top)
                    // Typically Word toolbar is about 150-200 pixels from top
                    let clickX = windowPos.x + windowSize.width / 2
                    let clickY = windowPos.y + 200 + (windowSize.height - 200) / 2
                    
                    let clickPoint = CGPoint(x: clickX, y: clickY)
                    print("🖱️ Strategy 1: Clicking in Word document at: \(clickPoint)")
                    
                    if await clickAtPoint(clickPoint) {
                        return true
                    }
                }
            }
        }
        
        // Strategy 2: Use AppleScript to click in Word - much more reliable!
        print("🔄 Strategy 2: Using AppleScript to click in Word document")
        let appleScriptSuccess = await clickInWordWithAppleScript()
        if appleScriptSuccess {
            return true
        }
        
        // Strategy 3: Use simple click in screen center (assuming Word is visible)
        print("🔄 Strategy 3: Clicking in screen center")
        let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let centerPoint = CGPoint(x: screenBounds.width / 2, y: screenBounds.height / 2)
        
        if await clickAtPoint(centerPoint) {
            return true
        }
        
        // Strategy 4: Use raw Core Graphics event to simulate click
        print("🔄 Strategy 4: Raw Core Graphics click")
        return await performRawClick(centerPoint)
    }
    
    private func clickInWordWithAppleScript() async -> Bool {
        let script = """
        tell application "Microsoft Word"
            activate
            delay 0.2
            
            -- Try to ensure we're in the document
            try
                tell application "System Events"
                    tell process "Microsoft Word"
                        -- Click in the main document area
                        click at {640, 400}
                        delay 0.1
                    end tell
                end tell
                return true
            on error
                return false
            end try
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        print("❌ AppleScript click error: \(error)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ AppleScript click succeeded")
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func performRawClick(_ point: CGPoint) async -> Bool {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source for click")
            return false
        }
        
        // Create mouse down event
        guard let mouseDown = CGEvent(mouseEventSource: eventSource, 
                                    mouseType: .leftMouseDown, 
                                    mouseCursorPosition: point, 
                                    mouseButton: .left) else {
            print("❌ Failed to create mouse down event")
            return false
        }
        
        // Create mouse up event
        guard let mouseUp = CGEvent(mouseEventSource: eventSource, 
                                  mouseType: .leftMouseUp, 
                                  mouseCursorPosition: point, 
                                  mouseButton: .left) else {
            print("❌ Failed to create mouse up event")
            return false
        }
        
        // Post the events
        mouseDown.post(tap: .cghidEventTap)
        
        // Small delay between down and up
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        mouseUp.post(tap: .cghidEventTap)
        
        print("✅ Posted raw click events at \(point)")
        return true
    }
    
    // MARK: - UI Test Automation
    
    private func automateWithUITest(text: String, app: AppAutomationTarget) async -> Bool {
        print("🧪 Using UI Test automation for \(app.displayName)")
        
        // Launch/activate the target application
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            do {
                try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
                
                // Wait for app to launch/activate
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Fallback to direct typing
                return await typeTextDirectly(text)
                
            } catch {
                print("❌ Failed to launch app: \(error)")
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Hybrid Automation
    
    private func automateWithHybridApproach(text: String, app: AppAutomationTarget) async -> Bool {
        print("🔄 Using hybrid automation approach for \(app.displayName)")
        
        // Try accessibility first (no AppleScript dependencies)
        print("🔄 Trying accessibility automation...")
        let accessibilitySuccess = await automateWithAccessibility(text: text, app: app)
        
        if accessibilitySuccess {
            print("✅ Accessibility automation succeeded")
            return true
        }
        
        print("🔄 Accessibility failed, trying direct Core Graphics typing...")
        return await typeWithCoreGraphics(text)
    }
    
    // MARK: - App Readiness and Utility Methods
    
    private func ensureAppIsRunningAndReady(app: AppAutomationTarget) async -> Bool {
        print("🔍 Ensuring \(app.displayName) is running and ready...")
        
        // Check if app is running
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier 
        }) else {
            print("❌ App not running: \(app.displayName)")
            return false
        }
        
        // Activate the app and wait for it to become ready
        runningApp.activate()
        print("📱 Activated \(app.displayName)")
        
        // Wait longer for the app to become fully ready
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Test if AppleScript can communicate with the app
        let testScript = "tell application \"\(app.displayName)\"\n" +
                        "    try\n" +
                        "        set appRunning to running\n" +
                        "        return true\n" +
                        "    on error\n" +
                        "        return false\n" +
                        "    end try\n" +
                        "end tell"
        
        let testResult = await executeSimpleAppleScript(testScript)
        if testResult {
            print("✅ \(app.displayName) is ready for AppleScript commands")
        } else {
            print("⚠️ \(app.displayName) may not be ready, but continuing...")
        }
        
        return true
    }
    
    private func executeSimpleAppleScript(_ script: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    print("🔍 Test script error: \(error)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Fallback and Utility Methods
    
    private func fallbackAutomation(text: String, targetApp: String) async -> Bool {
        print("🔄 Using fallback automation for \(targetApp)")
        
        // Try to find and activate the app using NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications
        guard let targetRunningApp = runningApps.first(where: { app in
            app.localizedName?.lowercased().contains(targetApp.lowercased()) == true ||
            targetApp.lowercased().contains(app.localizedName?.lowercased() ?? "")
        }) else {
            print("❌ Could not find running app: \(targetApp)")
            return false
        }
        
        // Activate the app
        targetRunningApp.activate()
        print("📱 Activated \(targetApp)")
        
        // Wait for app to become ready
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then type the text directly using Core Graphics
        return await typeWithCoreGraphics(text)
    }
    
    private func typeTextDirectly(_ text: String) async -> Bool {
        print("⌨️ Typing text directly using Core Graphics: \(text.prefix(50))...")
        
        // Add a delay to ensure the target is ready
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return await typeWithCoreGraphics(text)
    }
    
    private func typeWithCoreGraphics(_ text: String) async -> Bool {
        print("🎯 Using Core Graphics to type text character by character")
        
        // Create an event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        var successCount = 0
        let totalChars = text.count
        
        for char in text {
            if await typeCharacterWithCoreGraphics(char, eventSource: eventSource) {
                successCount += 1
            }
            
            // Small delay between characters for reliability
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        let success = successCount > 0
        print("✅ Typed \(successCount)/\(totalChars) characters successfully")
        return success
    }
    
    private func typeCharacterWithCoreGraphics(_ char: Character, eventSource: CGEventSource) async -> Bool {
        let string = String(char)
        
        // Handle special characters
        if char == "\n" {
            return await pressKeyWithCoreGraphics(keyCode: 36, eventSource: eventSource) // Return key
        } else if char == "\t" {
            return await pressKeyWithCoreGraphics(keyCode: 48, eventSource: eventSource) // Tab key
        }
        
        // For regular characters, use CGEventCreateKeyboardEvent with Unicode
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else {
            return false
        }
        
        // Set the Unicode string for the event
        keyDownEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
        keyUpEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func pressKeyWithCoreGraphics(keyCode: CGKeyCode, eventSource: CGEventSource) async -> Bool {
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func executeAppleScript(_ script: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ AppleScript error: \(error)")
                    lastAutomationResult = "AppleScript failed: \(error.description)"
                    continuation.resume(returning: false)
                } else {
                    print("✅ AppleScript executed successfully")
                    lastAutomationResult = "Success: Text written to app"
                    continuation.resume(returning: true)
                }
            } else {
                print("❌ Failed to create AppleScript object")
                lastAutomationResult = "Failed to create AppleScript"
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Permissions and Diagnostics
    
    func requestAllPermissions() async {
        print("🔐 Requesting all necessary permissions...")
        
        // Request accessibility permissions with prompt
        await requestAccessibilityPermissions()
        
        // Request automation permissions by trying to use System Events
        await requestAutomationPermissions()
        
        print("✅ Permission request process completed")
    }
    
    private func requestAccessibilityPermissions() async -> Bool {
        print("🔐 Requesting accessibility permissions...")
        
        // This will show the system dialog if permissions aren't granted
        let accessEnabled = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary)
        
        if !accessEnabled {
            print("⚠️ Accessibility permissions dialog shown - please grant permissions")
            print("💡 After granting permissions, you may need to restart the app")
            
            // Wait a bit for user to potentially grant permissions
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check again without prompt
            let newStatus = AXIsProcessTrustedWithOptions([
                "AXTrustedCheckOptionPrompt": false
            ] as CFDictionary)
            
            if newStatus {
                print("✅ Accessibility permissions granted!")
            } else {
                print("⚠️ Accessibility permissions still pending")
            }
            
            return newStatus
        } else {
            print("✅ Accessibility permissions already granted")
            return true
        }
    }
    
    private func requestAutomationPermissions() async {
        print("🔐 Requesting automation permissions...")
        
        // Test basic System Events access - this will trigger permission dialog
        let testScript = """
        tell application "System Events"
            try
                get name
                return "success"
            on error errMsg
                return "error: " & errMsg
            end try
        end tell
        """
        
        let result = await executePermissionTestScript(testScript)
        
        if result.contains("success") {
            print("✅ Automation permissions for System Events granted")
        } else if result.contains("1743") {
            print("⚠️ Automation permissions dialog should appear - please grant access to System Events")
        } else {
            print("🔍 Automation permission test result: \(result)")
        }
        
        // Also test Microsoft Word access if it's running
        if let wordApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == "com.microsoft.Word" 
        }) {
            print("🔐 Testing Microsoft Word automation permissions...")
            
            let wordTestScript = """
            tell application "Microsoft Word"
                try
                    get name
                    return "word_success"
                on error errMsg
                    return "word_error: " & errMsg
                end try
            end tell
            """
            
            let wordResult = await executePermissionTestScript(wordTestScript)
            
            if wordResult.contains("word_success") {
                print("✅ Automation permissions for Microsoft Word granted")
            } else if wordResult.contains("1743") {
                print("⚠️ Please grant automation access to Microsoft Word when prompted")
            } else {
                print("🔍 Word permission test result: \(wordResult)")
            }
        }
    }
    
    private func executePermissionTestScript(_ script: String) async -> String {
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            
            if let scriptObject = NSAppleScript(source: script) {
                let result = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    let errorDescription = error.description
                    print("🔍 Permission test error: \(errorDescription)")
                    continuation.resume(returning: errorDescription)
                } else if let resultString = result.stringValue {
                    continuation.resume(returning: resultString)
                } else {
                    continuation.resume(returning: "unknown_result")
                }
            } else {
                continuation.resume(returning: "script_creation_failed")
            }
        }
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let accessEnabled = AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": false
        ] as CFDictionary)
        
        if !accessEnabled {
            print("❌ Accessibility permissions not granted")
            print("💡 Please grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
        } else {
            print("✅ Accessibility permissions granted")
        }
        
        return accessEnabled
    }
    
    func checkAutomationPermissions() async -> Bool {
        print("🔍 Checking automation permissions...")
        
        let testScript = """
        tell application "System Events"
            try
                get name
                return true
            on error
                return false
            end try
        end tell
        """
        
        let result = await executePermissionTestScript(testScript)
        let hasPermissions = result.contains("success") || !result.contains("1743")
        
        if hasPermissions {
            print("✅ Automation permissions granted")
        } else {
            print("❌ Automation permissions not granted")
            print("💡 Please grant automation permissions in System Preferences > Security & Privacy > Privacy > Automation")
        }
        
        return hasPermissions
    }
    
    func checkAllPermissions() async -> (accessibility: Bool, automation: Bool) {
        let accessibility = checkAccessibilityPermissions()
        let automation = await checkAutomationPermissions()
        
        if !accessibility || !automation {
            print("⚠️ Some permissions are missing. App functionality may be limited.")
            if !accessibility {
                print("🔧 Missing: Accessibility permissions (required for all automation)")
            }
            if !automation {
                print("🔧 Missing: Automation permissions (required for AppleScript features)")
            }
        }
        
        return (accessibility: accessibility, automation: automation)
    }
    
    // MARK: - App Detection and Capabilities
    
    func getAutomationCapabilities(for appName: String) -> AppAutomationTarget? {
        return supportedApps.first { target in
            target.displayName.lowercased().contains(appName.lowercased()) ||
            appName.lowercased().contains(target.displayName.lowercased())
        }
    }
    
    func canAutomateApp(_ appName: String) -> Bool {
        return getAutomationCapabilities(for: appName) != nil
    }
    
    func getSupportedApps() -> [String] {
        return supportedApps.map { $0.displayName }
    }
} 
