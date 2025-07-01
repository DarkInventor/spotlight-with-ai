import Foundation
import AppKit
import ScreenCaptureKit
import Vision
import CoreGraphics
import ApplicationServices

@MainActor
class ContextManager: ObservableObject {
    @Published var currentContext: UserContext?
    @Published var isCapturingContext = false
    
    private var contextTimer: Timer?
    
    struct UserContext {
        let appName: String
        let windowTitle: String
        let screenshot: NSImage?
        let extractedText: String?
        let detectedActivity: String
        let timestamp: Date
        let canWriteIntoApp: Bool
    }
    
    init() {
        // Start monitoring context when app launches
        startContextMonitoring()
        // Setup hotkey context capture
        setupHotkeyContextCapture()
    }
    
    deinit {
        Task { @MainActor in
            stopContextMonitoring()
            // Clean up memory
            currentContext = nil
            hotkeyTriggeredContext = nil
        }
    }
    
    // MARK: - Context Monitoring
    
    private func startContextMonitoring() {
        // Capture context every 30 seconds when app is in background (reduced from 10s)
        // Only capture when user switches apps to save resources
        contextTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.captureCurrentContextLightweight()
            }
        }
        
        // Listen for app switching for real-time context updates (with delay to prevent freezing)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Add a delay to prevent freezing when apps are launching
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task {
                    await self?.captureCurrentContextLightweight()
                }
            }
        }
    }
    
    private func stopContextMonitoring() {
        contextTimer?.invalidate()
        contextTimer = nil
    }
    
    // MARK: - Hotkey Context Capture
    
    private var hotkeyTriggeredContext: UserContext?
    
    private func setupHotkeyContextCapture() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CaptureContextBeforeShow"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.object as? NSRunningApplication {
                print("🎯 RECEIVED CONTEXT CAPTURE NOTIFICATION for: \(app.localizedName ?? "Unknown")")
                Task {
                    await self?.captureContextForApp(app)
                    // Store this as the hotkey-triggered context
                    await MainActor.run {
                        self?.hotkeyTriggeredContext = self?.currentContext
                        print("🔒 LOCKED CONTEXT: \(self?.hotkeyTriggeredContext?.appName ?? "None")")
                    }
                }
            }
        }
        
        // Listen for window hide to clear locked context
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearLockedContext"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearLockedContext()
        }
    }
    
    // MARK: - Smart Context Capture
    
    // Ultra-lightweight version - no screenshots, no blocking operations
    func captureCurrentContextLightweight() async {
        // Early exit if already capturing
        guard !isCapturingContext else { return }
        
        // ALWAYS use locked context if available (never capture Searchfast context)
        if let lockedContext = hotkeyTriggeredContext {
            print("🔒 USING LOCKED CONTEXT: \(lockedContext.appName)")
            currentContext = lockedContext
            return
        }
        
        // Only capture new context if we don't have a locked one and frontmost is NOT Searchfast
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        if frontmostApp.contains("Searchfast") || frontmostApp.contains("search") {
            print("⚠️ Skipping context capture - frontmost is Searchfast")
            return
        }
        
        // Set flag to prevent multiple captures
        isCapturingContext = true
        defer { isCapturingContext = false }
        
        // Quick app info retrieval - don't block if slow
        let (appName, windowTitle) = await withTaskGroup(of: (String, String).self, returning: (String, String).self) { group in
            group.addTask {
                return await self.getFrontmostAppInfo()
            }
            
            // Add timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                return ("Unknown", "Unknown")
            }
            
            // Return first result (either app info or timeout)
            guard let result = await group.next() else {
                return ("Unknown", "Unknown")
            }
            group.cancelAll()
            return result
        }
        
        // Skip if app is launching (common freeze cause)
        if appName == "Unknown" || appName.isEmpty {
            print("⚠️ Skipping context capture - app launching or unknown")
            return
        }
        
        // Detect activity without screenshots (much faster)
        let detectedActivity = detectUserActivity(appName: appName, windowTitle: windowTitle, extractedText: nil)
        
        // Check if we can write into this app (cached lookup)
        let canWrite = canWriteIntoApp(appName)
        
        // Update context on main thread
        await MainActor.run {
            currentContext = UserContext(
                appName: appName,
                windowTitle: windowTitle,
                screenshot: nil, // No screenshot for background monitoring
                extractedText: nil,
                detectedActivity: detectedActivity,
                timestamp: Date(),
                canWriteIntoApp: canWrite
            )
        }
        
        print("⚡ Lightweight context: \(appName) - \(detectedActivity)")
    }
    
    func captureCurrentContext() async {
        guard !isCapturingContext else { return }
        
        // ALWAYS use locked context if available (never capture Searchfast context)
        if let lockedContext = hotkeyTriggeredContext {
            print("🔒 USING LOCKED CONTEXT: \(lockedContext.appName)")
            currentContext = lockedContext
            return
        }
        
        // Only capture new context if frontmost is NOT Searchfast
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        if frontmostApp.contains("Searchfast") || frontmostApp.contains("search") {
            print("⚠️ Skipping context capture - frontmost is Searchfast")
            return
        }
        
        isCapturingContext = true
        
        defer {
            isCapturingContext = false
        }
        
        do {
            // Get frontmost app info
            let (appName, windowTitle) = getFrontmostAppInfo()
            
            // Take invisible screenshot
            let screenshot = try await captureInvisibleScreenshot()
            
            // Extract text from screenshot
            let extractedText = await extractTextFromImage(screenshot)
            
            // Detect what user is doing based on app and content
            let detectedActivity = detectUserActivity(appName: appName, windowTitle: windowTitle, extractedText: extractedText)
            
            // Check if we can write into this app
            let canWrite = canWriteIntoApp(appName)
            
            currentContext = UserContext(
                appName: appName,
                windowTitle: windowTitle,
                screenshot: screenshot,
                extractedText: extractedText,
                detectedActivity: detectedActivity,
                timestamp: Date(),
                canWriteIntoApp: canWrite
            )
            
            print("📝 Context captured: \(appName) - \(detectedActivity)")
            
            // Schedule memory cleanup of old screenshots
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await self.cleanupOldScreenshots()
            }
            
        } catch {
            print("❌ Context capture failed: \(error)")
        }
    }
    
    // MARK: - Context Capture with Specific App
    
    func captureContextForApp(_ app: NSRunningApplication?) async {
        guard !isCapturingContext, let app = app else { return }
        isCapturingContext = true
        
        defer {
            isCapturingContext = false
        }
        
        do {
            let appName = app.localizedName ?? "Unknown"
            
            // Get window title using the specific app
            let windowTitle = getWindowTitleForApp(app) ?? "Unknown"
            
            // Take invisible screenshot
            let screenshot = try await captureInvisibleScreenshot()
            
            // Extract text from screenshot
            let extractedText = await extractTextFromImage(screenshot)
            
            // Detect what user is doing based on app and content
            let detectedActivity = detectUserActivity(appName: appName, windowTitle: windowTitle, extractedText: extractedText)
            
            // Check if we can write into this app
            let canWrite = canWriteIntoApp(appName)
            
            currentContext = UserContext(
                appName: appName,
                windowTitle: windowTitle,
                screenshot: screenshot,
                extractedText: extractedText,
                detectedActivity: detectedActivity,
                timestamp: Date(),
                canWriteIntoApp: canWrite
            )
            
            print("📝 Context captured for \(appName): \(detectedActivity)")
            
        } catch {
            print("❌ Context capture failed: \(error)")
        }
    }
    
    // MARK: - App Detection
    
    private func getFrontmostAppInfo() -> (String, String) {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return ("Unknown", "Unknown")
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        
        // Get window title using Accessibility API
        let windowTitle = getActiveWindowTitle() ?? "Unknown"
        
        return (appName, windowTitle)
    }
    
    // Get Chrome URL for super accurate detection
    private func getChromeURL() async -> String? {
        let script = """
        tell application "Google Chrome"
            if (count of windows) > 0 then
                try
                    return URL of active tab of first window
                on error
                    return ""
                end try
            else
                return ""
            end if
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            // CRITICAL FIX: Execute AppleScript on background thread to prevent UI freeze
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    Task { @MainActor in
                        if error == nil, let urlString = result.stringValue {
                            continuation.resume(returning: urlString.isEmpty ? nil : urlString)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    Task { @MainActor in
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    private func getActiveWindowTitle() -> String? {
        // Use Accessibility API to get the focused window title
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        guard result == .success, let app = focusedApp else { return nil }
        
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard windowResult == .success, let window = focusedWindow else { return nil }
        
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        
        guard titleResult == .success, let windowTitle = title as? String else { return nil }
        
        return windowTitle
    }
    
    private func getWindowTitleForApp(_ app: NSRunningApplication) -> String? {
        guard let pid = app.processIdentifier as pid_t? else { return nil }
        
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused window of this specific app
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if windowResult == .success, let window = focusedWindow {
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let windowTitle = title as? String {
                return windowTitle
            }
        }
        
        // If no focused window, try to get the main window
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        if windowsResult == .success, let windowArray = windows as? [AXUIElement], !windowArray.isEmpty {
            // Try to get title from the first window
            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(windowArray[0], kAXTitleAttribute as CFString, &title)
            
            if titleResult == .success, let windowTitle = title as? String {
                return windowTitle
            }
        }
        
        return nil
    }
    
    // MARK: - Invisible Screenshot
    
    private func captureInvisibleScreenshot() async throws -> NSImage {
        guard #available(macOS 12.3, *) else {
            throw ContextError.unsupportedOS
        }
        
        // Get all displays and windows
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first else {
            throw ContextError.noDisplayFound
        }
        
        // Create configuration for screenshot (much smaller for speed and memory)
        let config = SCStreamConfiguration()
        config.width = 800 // Much smaller for speed (was 1920)
        config.height = 600  // Much smaller for speed (was 1080)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false // Don't need cursor for context
        config.scalesToFit = true
        
        // Create filter excluding our own window
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Take screenshot
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    // MARK: - Text Extraction
    
    private func extractTextFromImage(_ image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Text recognition error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Take only top 10 results to reduce processing time
                let recognizedStrings = request.results?.prefix(10).compactMap { result in
                    (result as? VNRecognizedTextObservation)?.topCandidates(1).first?.string
                } ?? []
                
                let extractedText = recognizedStrings.joined(separator: " ")
                // Truncate to save memory and processing time
                let truncatedText = String(extractedText.prefix(1000)) // Max 1KB of text
                continuation.resume(returning: truncatedText.isEmpty ? nil : truncatedText)
            }
            
            request.recognitionLevel = .fast // Use fast recognition for background monitoring
            request.usesLanguageCorrection = false // Disable for speed
            request.minimumTextHeight = 0.05 // Only detect larger text for speed
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Activity Detection
    
    private func detectUserActivity(appName: String, windowTitle: String, extractedText: String?) -> String {
        let appLower = appName.lowercased()
        let titleLower = windowTitle.lowercased()
        let textLower = extractedText?.lowercased() ?? ""
        
        print("🔍 Context Debug:")
        print("  App: \(appName)")
        print("  Window Title: \(windowTitle)")
        print("  Extracted Text: \(extractedText?.prefix(100) ?? "None")")
        
        // Detect specific activities based on app and content
        switch appLower {
        case let app where app.contains("chrome") || app.contains("safari") || app.contains("firefox"):
            // For Chrome, get the actual URL for 100% accurate detection
            if app.contains("chrome") {
                Task {
                    if let chromeURL = await getChromeURL() {
                        print("🌐 Chrome URL: \(chromeURL)")
                        // Update context with URL info - this will be used for next detection cycle
                    }
                }
            }
            
            // ENHANCED URL DETECTION - check multiple sources
            let combinedText = "\(titleLower) \(textLower)"
            
            // Google Docs detection (multiple patterns)
            if combinedText.contains("docs.google.com/document") ||
               combinedText.contains("google docs") ||
               (combinedText.contains("document") && combinedText.contains("google")) ||
               combinedText.contains("untitled document") ||
               titleLower.hasPrefix("document") ||
               titleLower.contains("- google docs") ||
               titleLower.hasSuffix("- google docs") {
                return "Writing in Google Docs"
            }
            // Gmail detection (multiple patterns)  
            else if combinedText.contains("mail.google.com") ||
                    combinedText.contains("gmail") ||
                    titleLower.contains("gmail") ||
                    combinedText.contains("inbox") && combinedText.contains("google") {
                return "Managing email in Gmail"
            } else if combinedText.contains("docs.google.com/spreadsheets") ||
                      combinedText.contains("sheets.google.com") ||
                      combinedText.contains("google sheets") ||
                      titleLower.contains("spreadsheet") ||
                      titleLower.contains("untitled spreadsheet") ||
                      titleLower.hasSuffix("- google sheets") {
                return "Working in Google Sheets"
            } else if titleLower.contains("slack") || textLower.contains("slack") {
                return "Chatting in Slack"
            } else if titleLower.contains("github") || textLower.contains("github") {
                return "Coding on GitHub"
            } else if titleLower.contains("slides") || 
                      titleLower.contains("slides.google.com") ||
                      textLower.contains("slides.google.com") {
                return "Creating presentation in Google Slides"
            } else {
                return "Browsing the web in \(appName)"
            }
            
        case let app where app.contains("pages"):
            return "Writing in Pages"
            
        case let app where app.contains("word"):
            return "Writing in Microsoft Word"
            
        case let app where app.contains("xcode"):
            return "Coding in Xcode"
            
        case let app where app.contains("vs code") || app.contains("visual studio"):
            return "Coding in VS Code"
            
        case let app where app.contains("cursor") || app.contains("Cursor"):
            return "Coding in Cursor IDE"
            
        case let app where app.contains("slack"):
            return "Chatting in Slack"
            
        case let app where app.contains("discord"):
            return "Chatting in Discord"
            
        case let app where app.contains("excel"):
            return "Working in Microsoft Excel"
            
        case let app where app.contains("powerpoint"):
            return "Creating presentation in Microsoft PowerPoint"
            
        case let app where app.contains("numbers"):
            return "Working in Numbers spreadsheet"
            
        case let app where app.contains("keynote"):
            return "Creating presentation in Keynote"
            
        case let app where app.contains("mail"):
            return "Managing email in Mail"
            
        case let app where app.contains("notion"):
            return "Working in Notion"
            
        case let app where app.contains("zoom"):
            return "In a Zoom meeting"
            
        case let app where app.contains("teams"):
            return "In a Microsoft Teams meeting"
            
        case let app where app.contains("messages"):
            return "Messaging"
            
        case let app where app.contains("facetime"):
            return "In a FaceTime call"
            
        case let app where app.contains("spotify"):
            return "Listening to music on Spotify"
            
        case let app where app.contains("textedit"):
            return "Editing text in TextEdit"
            
        case let app where app.contains("notes"):
            return "Taking notes"
            
        default:
            return "Using \(appName)"
        }
    }
    
    // MARK: - Writing Capability Detection
    
    private func canWriteIntoApp(_ appName: String) -> Bool {
        let appLower = appName.lowercased()
        
        // NEVER allow writing to Searchfast itself!
        if appLower.contains("searchfast") || appLower.contains("search") {
            print("🚫 BLOCKED: Cannot write to Searchfast itself!")
            return false
        }
        
        let writableApps = [
            "google chrome", "safari", "firefox", // For web apps including Google Sheets, Docs, Gmail
            "pages", "microsoft word", "microsoft excel", "microsoft powerpoint",
            "numbers", "keynote", "textedit", "notes",
            "xcode", "visual studio code", "vs code", "cursor",
            "slack", "discord", "mail", "messages", "notion",
            "atom", "sublime", "vim", "emacs" // Additional code editors
        ]
        
        return writableApps.contains { appLower.contains($0) }
    }
    
    // MARK: - Smart AI Integration
    
    func getContextualPrompt(for userQuery: String, includeScreenshotContext: Bool = false) -> String {
        guard let context = currentContext else {
            return """
            🤖 AI AGENT MODE: You are an intelligent AI assistant that can see and interact with the user's screen. 
            
            IMPORTANT: The user expects you to show your response FIRST with action buttons, not execute actions immediately. Be conversational and helpful.
            
            User's request: \(userQuery)
            """
        }
        
        var contextualPrompt = """
        🤖 AI AGENT MODE: You are an intelligent AI assistant with screen awareness and automation capabilities.
        
        🎯 CURRENT CONTEXT:
        - Activity: \(context.detectedActivity)
        - App: \(context.appName)
        - Window: \(context.windowTitle)
        
        """
        
        if includeScreenshotContext {
            contextualPrompt += """
            📸 VISUAL CONTEXT: I can see your current screen automatically captured when you opened this assistant. I understand what you're working on and can provide specific help based on what's visible.
            
            """
        }
        
        if let extractedText = context.extractedText, !extractedText.isEmpty {
            // Include relevant snippet of what's on screen
            let snippet = String(extractedText.prefix(300)) // Reduced for better prompting
            contextualPrompt += "📝 Screen content: \(snippet)\n\n"
        }
        
        // App-specific guidance
        let appSpecificGuidance = getAppSpecificGuidance(for: context.appName)
        if !appSpecificGuidance.isEmpty {
            contextualPrompt += "\(appSpecificGuidance)\n\n"
        }
        
        if context.canWriteIntoApp {
            contextualPrompt += """
            ✨ AUTOMATION READY: I can write directly into \(context.appName) for you. Just ask me what you need and I'll show you the response first, then provide action buttons to execute.
            
            """
        }
        
        contextualPrompt += """
        🎯 RESPONSE STYLE:
        - Be conversational and helpful, like Cursor IDE's AI
        - Show your analysis/answer FIRST 
        - Don't immediately execute actions - let the user see your response
        - If you can help with automation (writing code, text, opening apps, web searches), mention it naturally
        - Be specific about what you see on their screen when relevant
        - Provide actionable suggestions based on their current work
        
        💭 User's question: \(userQuery)
        
        Remember: Show your response first, then action buttons will appear automatically for any actions I can perform.
        """
        
        return contextualPrompt
    }
    
    private func getAppSpecificGuidance(for appName: String) -> String {
        let appLower = appName.lowercased()
        
        switch appLower {
        case let app where app.contains("cursor"):
            return "💻 CURSOR IDE DETECTED: I can help with code review, writing new code, debugging, explaining code, and implementing features. I can write code directly into your editor."
            
        case let app where app.contains("visual studio code") || app.contains("vs code"):
            return "💻 VS CODE DETECTED: I can help with coding tasks, write code snippets, debug issues, and explain code. I can insert code directly into your editor."
            
        case let app where app.contains("xcode"):
            return "🔨 XCODE DETECTED: I can help with Swift/Objective-C development, debugging, and iOS/macOS app development. I can write code directly into Xcode."
            
        case let app where app.contains("chrome") || app.contains("safari") || app.contains("firefox"):
            return "🌐 BROWSER DETECTED: I can help you navigate websites, search the web, fill forms, and assist with web-based work. I can perform web searches and open specific sites."
            
        case let app where app.contains("word"):
            return "📝 MICROSOFT WORD DETECTED: I can help with writing, editing, formatting documents, and content creation. I can write text directly into your document."
            
        case let app where app.contains("excel"):
            return "📊 EXCEL DETECTED: I can help with spreadsheet tasks, formulas, data analysis, and formatting. I can insert content directly into Excel."
            
        case let app where app.contains("pages"):
            return "📄 PAGES DETECTED: I can help with document creation, writing, and formatting. I can write text directly into Pages."
            
        case let app where app.contains("photoshop"):
            return "🎨 PHOTOSHOP DETECTED: I can help with photo editing techniques, layer management, effects, and design guidance based on what's visible on your screen."
            
        case let app where app.contains("illustrator"):
            return "🎨 ILLUSTRATOR DETECTED: I can help with vector design, typography, color schemes, and design techniques based on your current artwork."
            
        case let app where app.contains("figma"):
            return "🎨 FIGMA DETECTED: I can help with UI/UX design, prototyping, component creation, and design systems based on your current work."
            
        default:
            return ""
        }
    }
    
    // MARK: - Write Into App
    
    func writeIntoCurrentApp(_ text: String) async {
        guard let context = currentContext, context.canWriteIntoApp else {
            print("❌ Cannot write into current app: \(currentContext?.appName ?? "unknown")")
            return
        }
        
        // Hide our window first
        if let windowManager = NSApp.delegate as? WindowManager {
            windowManager.hideWindow()
        }
        
        // Wait for window to hide
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Use advanced automation manager for better reliability
        let automationManager = AppAutomationManager()
        let success = await automationManager.automateWriting(text: text, targetApp: context.appName)
        
        if !success {
            print("🔄 Advanced automation failed, trying fallback...")
            // Fallback to original method
            await bringAppToFrontAndType(appName: context.appName, text: text)
        } else {
            print("✅ Advanced automation succeeded!")
        }
        
        // Clear the locked context after writing
        await MainActor.run {
            hotkeyTriggeredContext = nil
            print("🔓 CLEARED LOCKED CONTEXT after writing")
        }
    }
    
    func clearLockedContext() {
        hotkeyTriggeredContext = nil
        print("🔓 MANUALLY CLEARED LOCKED CONTEXT")
    }
    
    // MARK: - Memory Management
    
    private func cleanupOldScreenshots() async {
        await MainActor.run {
            if let context = currentContext, context.timestamp.timeIntervalSinceNow < -30 {
                // Remove screenshot from old context to save memory
                currentContext = UserContext(
                    appName: context.appName,
                    windowTitle: context.windowTitle,
                    screenshot: nil, // Clear old screenshot
                    extractedText: context.extractedText,
                    detectedActivity: context.detectedActivity,
                    timestamp: context.timestamp,
                    canWriteIntoApp: context.canWriteIntoApp
                )
                print("🧹 Cleaned up old screenshot to save memory")
            }
        }
    }
    
    private func bringAppToFrontAndType(appName: String, text: String) async {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "\(escapedAppName)"
            activate
        end tell
        
        delay 0.5
        
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        // CRITICAL FIX: Execute AppleScript on background thread to prevent UI freeze
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                Task { @MainActor in
                    if let error = error {
                        print("❌ AppleScript error: \(error)")
                    } else {
                        print("✅ Successfully typed into \(appName)")
                    }
                }
            }
        }
    }
}

// MARK: - Errors

enum ContextError: Error {
    case unsupportedOS
    case noDisplayFound
    case screenshotFailed
} 
