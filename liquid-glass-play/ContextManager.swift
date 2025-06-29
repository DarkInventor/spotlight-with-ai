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
        }
    }
    
    // MARK: - Context Monitoring
    
    private func startContextMonitoring() {
        // Capture context every 10 seconds when app is in background
        contextTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.captureCurrentContext()
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
    
    func captureCurrentContext() async {
        guard !isCapturingContext else { return }
        
        // If we have a hotkey-triggered context and frontmost app is Searchfast, use the locked context
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        if frontmostApp == "Searchfast" || frontmostApp.contains("search"), 
           let lockedContext = hotkeyTriggeredContext {
            print("🔒 USING LOCKED CONTEXT: \(lockedContext.appName) (frontmost is \(frontmostApp))")
            currentContext = lockedContext
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
        
        // Create configuration for screenshot (smaller for performance)
        let config = SCStreamConfiguration()
        config.width = 1920 // Smaller than full resolution for speed
        config.height = 1080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false // Don't need cursor for context
        
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
                
                let recognizedStrings = request.results?.compactMap { result in
                    (result as? VNRecognizedTextObservation)?.topCandidates(1).first?.string
                } ?? []
                
                let extractedText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: extractedText.isEmpty ? nil : extractedText)
            }
            
            request.recognitionLevel = .fast // Use fast recognition for background monitoring
            request.usesLanguageCorrection = true
            
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
            // Check URL in window title or extracted text for better detection
            if titleLower.contains("google docs") || 
               titleLower.contains("docs.google.com") ||
               titleLower.contains("document") && titleLower.contains("google") ||
               textLower.contains("docs.google.com") ||
               textLower.contains("https://docs.google.com") ||
               (titleLower.contains("untitled document") && appLower.contains("chrome")) ||
               (titleLower.contains("document") && appLower.contains("chrome")) {
                return "Writing in Google Docs"
            } else if titleLower.contains("gmail") || 
                      titleLower.contains("mail.google.com") ||
                      textLower.contains("gmail") {
                return "Managing email in Gmail"
            } else if titleLower.contains("slack") || textLower.contains("slack") {
                return "Chatting in Slack"
            } else if titleLower.contains("github") || textLower.contains("github") {
                return "Coding on GitHub"
            } else if titleLower.contains("sheets") || 
                      titleLower.contains("sheets.google.com") ||
                      textLower.contains("sheets.google.com") {
                return "Working in Google Sheets"
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
        let writableApps = [
            "google chrome", "safari", "firefox", // For web apps including Google Sheets, Docs, Gmail
            "pages", "microsoft word", "microsoft excel", "microsoft powerpoint",
            "numbers", "keynote", "textedit", "notes",
            "xcode", "visual studio code", "vs code",
            "slack", "discord", "mail", "messages", "notion",
            "atom", "sublime", "vim", "emacs" // Additional code editors
        ]
        
        return writableApps.contains { appName.lowercased().contains($0) }
    }
    
    // MARK: - Smart AI Integration
    
    func getContextualPrompt(for userQuery: String) -> String {
        guard let context = currentContext else {
            return userQuery
        }
        
        var contextualPrompt = """
        User is currently \(context.detectedActivity).
        App: \(context.appName)
        Window: \(context.windowTitle)
        
        """
        
        if let extractedText = context.extractedText, !extractedText.isEmpty {
            // Include relevant snippet of what's on screen
            let snippet = String(extractedText.prefix(500)) // First 500 chars
            contextualPrompt += "Current content visible: \(snippet)\n\n"
        }
        
        contextualPrompt += "User's request: \(userQuery)"
        
        return contextualPrompt
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
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("❌ AppleScript error: \(error)")
            } else {
                print("✅ Successfully typed into \(appName)")
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
