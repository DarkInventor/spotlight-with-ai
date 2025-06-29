import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
class AppAutomationManager: ObservableObject {
    @Published var isAutomating = false
    @Published var lastAutomationResult: String = ""
    
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
            supportedActions: [.typeText(""), .insertAtCursor(""), .replaceSelection("")]
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
    
    // MARK: - Main Automation Interface
    
    func automateWriting(text: String, targetApp: String) async -> Bool {
        guard !isAutomating else { return false }
        
        isAutomating = true
        defer { isAutomating = false }
        
        print("🤖 Starting automation for \(targetApp) with text: \(text.prefix(50))...")
        
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
    
    // MARK: - AppleScript Automation
    
    private func automateWithAppleScript(text: String, app: AppAutomationTarget) async -> Bool {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAppName = app.displayName.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script: String
        
        switch app.displayName {
        case "Google Chrome":
            // Check current URL to determine what we're automating
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.7
                
                -- Get current URL to determine automation strategy
                set currentURL to URL of active tab of first window
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        if currentURL contains "docs.google.com/spreadsheets" then
                            -- Google Sheets automation
                            try
                                -- Click on currently selected cell
                                click at {600, 400}
                                delay 0.3
                                
                                -- Press F2 or Enter to start editing
                                key code 120 -- F2 key
                                delay 0.2
                            on error
                                try
                                    -- Alternative: double-click to edit
                                    click at {600, 400}
                                    click at {600, 400}
                                    delay 0.3
                                end try
                            end try
                            
                        else if currentURL contains "docs.google.com/document" then
                            -- Google Docs automation
                            try
                                click (first UI element whose role is "AXWebArea")
                                delay 0.3
                            on error
                                click at {700, 400}
                                delay 0.3
                            end try
                            
                        else if currentURL contains "gmail.com" then
                            -- Gmail automation
                            try
                                -- Look for Gmail compose area
                                click at {700, 400} -- Common Gmail compose body location
                                delay 0.3
                            on error
                                try
                                    -- Alternative: click on web area
                                    click (first UI element whose role is "AXWebArea")
                                    delay 0.3
                                on error
                                    -- Final fallback: click center of window
                                    click at {800, 500}
                                    delay 0.3
                                end try
                            end try
                            
                            -- Ensure we're in the right place by clicking again
                            try
                                click at {700, 450}
                                delay 0.2
                            end try
                            
                        else
                            -- Generic web page automation
                            try
                                click (first UI element whose role is "AXWebArea")
                                delay 0.3
                            on error
                                click at {700, 400}
                                delay 0.3
                            end try
                        end if
                    end tell
                    
                    -- Type the text
                    keystroke "\(escapedText)"
                    
                    -- For Google Sheets, press Enter to confirm
                    if currentURL contains "docs.google.com/spreadsheets" then
                        key code 36 -- Enter key
                    end if
                end tell
            end tell
            """
            
        case "Safari":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        try
                            click (first UI element whose role is "AXWebArea")
                        on error
                            -- Fallback: just type
                        end try
                    end tell
                    
                    delay 0.2
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        case "Pages":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        case "Microsoft Word":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.7
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Find the document text area
                        try
                            click (first text area)
                            delay 0.2
                        on error
                            try
                                -- Alternative: click on scroll area
                                click (first scroll area)
                                delay 0.2
                            end try
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        case "Microsoft Excel":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.7
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Focus on the current cell
                        try
                            -- Press F2 to edit current cell
                            key code 120 -- F2 key
                            delay 0.2
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                    
                    -- Press Enter to confirm entry
                    key code 36 -- Enter key
                end tell
            end tell
            """
            
        case "Microsoft PowerPoint":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.7
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Try to click on slide content area
                        try
                            click (first text area)
                            delay 0.2
                        on error
                            try
                                click (first scroll area)
                                delay 0.2
                            end try
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        case "Numbers":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Try to focus on current cell
                        try
                            -- Double-click to edit current cell
                            click (first text field)
                            delay 0.2
                        on error
                            -- Just try typing
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                    key code 36 -- Enter to confirm
                end tell
            end tell
            """
            
        case "Keynote":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Try to click on slide content
                        try
                            click (first text area)
                            delay 0.2
                        on error
                            try
                                click (first scroll area)
                                delay 0.2
                            end try
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        case "Mail":
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    tell process "\(escapedAppName)"
                        -- Try to find compose window
                        try
                            click (first text area)
                            delay 0.2
                        on error
                            -- Fallback to typing
                        end try
                    end tell
                    
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
            
        default:
            script = """
            tell application "\(escapedAppName)"
                activate
                delay 0.5
                
                tell application "System Events"
                    keystroke "\(escapedText)"
                end tell
            end tell
            """
        }
        
        return await executeAppleScript(script)
    }
    
    // MARK: - Accessibility Automation
    
    private func automateWithAccessibility(text: String, app: AppAutomationTarget) async -> Bool {
        // Find the target application
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier 
        }) else {
            print("❌ App not running: \(app.displayName)")
            return false
        }
        
        // Bring app to front
        runningApp.activate(options: [.activateIgnoringOtherApps])
        
        // Wait for app to become active
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Get app element
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        
        // Find focused text field and insert text
        return await insertTextInFocusedElement(appElement: appElement, text: text)
    }
    
    private func insertTextInFocusedElement(appElement: AXUIElement, text: String) async -> Bool {
        // For Gmail/Web apps, try to find the compose area first
        if let composeArea = await findGmailComposeArea(in: appElement) {
            print("🎯 Found Gmail compose area!")
            return await insertTextInElement(composeArea, text: text)
        }
        
        // Get focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            // Fallback to typing directly
            return await typeTextDirectly(text)
        }
        
        // Try to insert text at cursor position
        let axElement = element as! AXUIElement
        
        // Get current selection
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        if rangeResult == .success, let range = selectedRange {
            // Insert text at selection
            let insertResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, text as CFString)
            return insertResult == .success
        }
        
        // Fallback to typing
        return await typeTextDirectly(text)
    }
    
    private func findGmailComposeArea(in appElement: AXUIElement) async -> AXUIElement? {
        // Look for Gmail-specific elements
        return await searchForGmailElements(in: appElement)
    }
    
    private func searchForGmailElements(in element: AXUIElement) async -> AXUIElement? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                // Check if this element might be a compose area
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let roleString = role as? String {
                    // Look for text areas, web areas, or editable content
                    if roleString == "AXTextArea" || roleString == "AXWebArea" {
                        // Check if it's editable
                        var value: CFTypeRef?
                        let valueResult = AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &value)
                        if valueResult == .success {
                            return child
                        }
                    }
                }
                
                // Recursively search children
                if let found = await searchForGmailElements(in: child) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    // MARK: - UI Test Automation (XCUITest-inspired)
    
    private func automateWithUITest(text: String, app: AppAutomationTarget) async -> Bool {
        // This simulates XCUITest approach for macOS
        print("🧪 Using UI Test automation for \(app.displayName)")
        
        // Launch/activate the target application
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            do {
                try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
                
                // Wait for app to launch/activate
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Find and interact with UI elements
                return await findAndAutomateUIElements(text: text, app: app)
                
            } catch {
                print("❌ Failed to launch app: \(error)")
                return false
            }
        }
        
        return false
    }
    
    private func findAndAutomateUIElements(text: String, app: AppAutomationTarget) async -> Bool {
        // This would use accessibility to find specific UI elements
        // Similar to XCUITest's element queries
        
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier 
        }) else {
            return false
        }
        
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        
        // Find text fields, web areas, or document areas
        if let textElement = await findTextInputElement(in: appElement, for: app) {
            return await insertTextInElement(textElement, text: text)
        }
        
        // Fallback to direct typing
        return await typeTextDirectly(text)
    }
    
    private func findTextInputElement(in appElement: AXUIElement, for app: AppAutomationTarget) async -> AXUIElement? {
        // Search for text input elements based on app type
        let searchRoles: [String]
        
        switch app.displayName {
        case "Google Chrome", "Safari":
            searchRoles = ["AXWebArea", "AXTextField", "AXTextArea"]
        case "Pages", "Microsoft Word":
            searchRoles = ["AXTextArea", "AXTextField", "AXScrollArea"]
        default:
            searchRoles = ["AXTextField", "AXTextArea", "AXScrollArea"]
        }
        
        return await searchForElementWithRoles(in: appElement, roles: searchRoles)
    }
    
    private func searchForElementWithRoles(in element: AXUIElement, roles: [String]) async -> AXUIElement? {
        // Implementation would recursively search the accessibility tree
        // This is a simplified version
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let childArray = children as? [AXUIElement] {
            for child in childArray {
                var role: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                
                if roleResult == .success, let roleString = role as? String, roles.contains(roleString) {
                    return child
                }
                
                // Recursively search children
                if let found = await searchForElementWithRoles(in: child, roles: roles) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func insertTextInElement(_ element: AXUIElement, text: String) async -> Bool {
        // Focus the element first
        let focusResult = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        if focusResult == .success {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Insert text
            let insertResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
            return insertResult == .success
        }
        
        return false
    }
    
    // MARK: - Hybrid Automation
    
    private func automateWithHybridApproach(text: String, app: AppAutomationTarget) async -> Bool {
        print("🔄 Using hybrid automation approach for \(app.displayName)")
        
        // Try accessibility first, fallback to AppleScript
        let accessibilitySuccess = await automateWithAccessibility(text: text, app: app)
        
        if accessibilitySuccess {
            print("✅ Accessibility automation succeeded")
            return true
        }
        
        print("🔄 Accessibility failed, trying AppleScript...")
        return await automateWithAppleScript(text: text, app: app)
    }
    
    // MARK: - Fallback and Utility Methods
    
    private func fallbackAutomation(text: String, targetApp: String) async -> Bool {
        print("🔄 Using fallback automation for \(targetApp)")
        
        // Generic approach: activate app and type
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAppName = targetApp.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "\(escapedAppName)"
            activate
        end tell
        
        delay 0.5
        
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        return await executeAppleScript(script)
    }
    
    private func typeTextDirectly(_ text: String) async -> Bool {
        print("⌨️ Typing text directly: \(text.prefix(50))...")
        
        // Add a small delay to ensure the target is ready
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // For Gmail, try to click first to ensure focus
        let clickScript = """
        tell application "System Events"
            tell process "Google Chrome"
                try
                    -- Click in the compose area
                    click at {700, 400}
                    delay 0.2
                    click at {700, 450}
                    delay 0.2
                end try
            end tell
        end tell
        """
        
        _ = await executeAppleScript(clickScript)
        
        // Now type the text using System Events (more reliable than CGEvents)
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let typeScript = """
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        let success = await executeAppleScript(typeScript)
        
        if success {
            print("✅ Text typed successfully via System Events")
        } else {
            print("🔄 System Events failed, trying CGEvents...")
            // Fallback to character-by-character typing
            return await typeWithCGEvents(text)
        }
        
        return success
    }
    
    private func typeWithCGEvents(_ text: String) async -> Bool {
        // Direct keyboard event simulation as fallback
        for char in text {
            guard let keyCode = characterToKeyCode(char) else { continue }
            
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            // Small delay between characters for reliability
            try? await Task.sleep(nanoseconds: 15_000_000) // 0.015 seconds
        }
        
        print("✅ Text typed via CGEvents")
        return true
    }
    
    private func characterToKeyCode(_ char: Character) -> CGKeyCode? {
        // Basic character to key code mapping
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
            "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
            "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            " ": 49, "\n": 36, "\t": 48
        ]
        
        return keyMap[Character(char.lowercased())]
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