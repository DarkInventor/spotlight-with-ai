import CoreFoundation
import SwiftUI
import GoogleGenerativeAI
import SwiftfulLoadingIndicators
import ScreenCaptureKit
import CoreMedia
import AppKit

struct ContentView: View {
    @State private var searchText: String = ""
    @State private var response: LocalizedStringKey = "How can I help you today?"
    @State private var responseText: String = "How can I help you today?"
    @State private var showingProactiveGreeting = false
    @State private var isLoading = false
    @State private var isCopied = false
    @State private var selectedImage: NSImage? = nil
    @State private var autoScreenshot: NSImage? = nil
    @State private var showingActionButtons = false
    @State private var pendingActions: [ResponseAction] = []
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var universalSearchManager = UniversalSearchManager()
    @StateObject private var contextManager = ContextManager()
    @StateObject private var automationManager = AppAutomationManager()
    @StateObject private var screenshotManager = ScreenshotManager() // NEW: Dedicated screenshot manager
    @StateObject private var appSearchManager = AppSearchManager() // NEW: For app launching
    @StateObject private var speechManager = SpeechManager() // NEW: Speech recognition manager
    @StateObject private var firebaseManager = FirebaseManager() // NEW: Firebase manager
    @State private var showingHotkeyInstructions = false
    @State private var showingUniversalResults = false
    @State private var isCapturingScreenshot = false
    @State private var shouldWriteToApp = false
    @State private var isSpeechMode = false // NEW: Track if speech mode is active
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var windowManager: WindowManager
    
    // 🎉 NEW: Onboarding state management
    @State private var showingOnboarding = false
    @State private var hasCompletedOnboarding = false
    
    // NEW: Response actions structure
    struct ResponseAction: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let description: String
        let actionType: ActionType
        let payload: String
        
        enum ActionType {
            case writeToApp
            case openApp
            case executeScript
            case copyText
            case searchWeb
        }
    }
    
    // Before running, please ensure you have added the GoogleGenerativeAI package.
    // In Xcode: File > Add Package Dependencies... > https://github.com/google/generative-ai-swift
    private let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: APIKey.default)

    var body: some View {
        ZStack {
            // 🎉 Main app content - only show when onboarding is complete
            if hasCompletedOnboarding && !showingOnboarding {
                mainContentView
            }
            
            // 🎉 Onboarding overlay - show when needed
            if showingOnboarding {
                OnboardingView(isPresented: $showingOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1000) // Ensure onboarding is on top
            }
        }
        // REMOVED: .background(Color.clear) or any .liquidGlassSpotlight() here
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingOnboarding)
        .onAppear {
            checkOnboardingStatus()
        }
        .onChange(of: firebaseManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // User just authenticated - hide onboarding
                withAnimation {
                    showingOnboarding = false
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
                
                // Log app usage
                Task {
                    await firebaseManager.logAppUsage()
                }
            } else {
                // User logged out or not authenticated - show onboarding
                withAnimation {
                    showingOnboarding = true
                    hasCompletedOnboarding = false
                }
            }
        }
        .onChange(of: windowManager.isFirstLaunch) { isFirstLaunch in
            if isFirstLaunch && !hasCompletedOnboarding {
                print("🎉 WindowManager indicates first launch - preparing onboarding")
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowOnboarding"))) { _ in
            withAnimation {
                showingOnboarding = true
                
                // Resize window for onboarding
                windowManager.showOnboardingWindow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowOnboardingOnFirstLaunch"))) { _ in
            print("🎉 Received first launch onboarding notification")
            withAnimation {
                hasCompletedOnboarding = false
                showingOnboarding = true
            }
        }
        .onChange(of: showingOnboarding) { isShowing in
            // When onboarding is dismissed, update the completed status and reset window size
            if !isShowing {
                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                
                // Mark first launch as complete
                windowManager.isFirstLaunch = false
                
                // Reset window to normal size when onboarding is dismissed
                windowManager.hideOnboardingWindow()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // REMOVED: .background(Color.clear) // Transparent background for the window
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowHotkeyInstructions"))) { _ in
            showingHotkeyInstructions = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CaptureContext"))) { _ in
            Task {
                // Small delay to ensure the previous app is still frontmost
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await contextManager.captureCurrentContext()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CaptureContextBeforeShow"))) { notification in
            Task {
                // Capture context for the specific app that was frontmost
                if let app = notification.object as? NSRunningApplication {
                    print("🎯 ContentView: Received context capture notification for \(app.localizedName ?? "Unknown")")
                    
                    // 🐱 CAT-SAVING: Capture Word cursor position if it's Word
                    if app.bundleIdentifier == "com.microsoft.Word" ||
                       app.localizedName?.lowercased().contains("word") == true {
                        print("📍 🐱 Capturing Word cursor position before switching away!")
                        await automationManager.captureWordCursorPosition()
                    }
                    
                    // 🚀 NEW: Automatically capture screenshot for context
                    print("📸 🚀 AUTO-CAPTURING SCREENSHOT for intelligent context awareness!")
                    if let screenshot = await screenshotManager.captureForContext() {
                        autoScreenshot = screenshot
                        print("✅ 🚀 AUTO-SCREENSHOT SET! Ready for intelligent responses!")
                    }
                    
                    await contextManager.captureContextForApp(app)
                    
                    // Force UI update
                    await MainActor.run {
                        print("🔄 Current context after capture: \(contextManager.currentContext?.appName ?? "None")")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideSearchWindow"))) { _ in
            print("📱 Received HideSearchWindow notification")
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
        }
        .onAppear {
            checkAndShowHotkeyInstructions()
            showProactiveGreeting()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutoProcessSpeech"))) { notification in
            if let speechText = notification.object as? String, !speechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("🎤 Auto-processing speech: '\(speechText)'")
                Task {
                    await processSpeechInput(speechText)
                }
            } else {
                // This handles the case of a silence timeout with no speech.
                print("🎤 Silence timeout, no speech detected. Exiting speech mode.")
                isSpeechMode = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartSpeechMode"))) { _ in
            enterSpeechMode()
        }
        .alert("Save Conversation History?", isPresented: $memoryManager.showingPermissionAlert) {
            Button("Allow") {
                memoryManager.grantPermission()
            }
            Button("Don't Save", role: .cancel) {
                memoryManager.denyPermission()
            }
        } message: {
            Text("Would you like to save your conversation history to a local file for better context? This helps the AI remember your previous questions. The file will be saved in your Documents folder.")
        }
        .alert("Enable Universal Search?", isPresented: $universalSearchManager.showingPermissionAlert) {
            Button("Allow") {
                universalSearchManager.grantPermission()
                UserDefaults.standard.set(true, forKey: "universalSearchPermissionAsked")
            }
            Button("No Thanks", role: .cancel) {
                universalSearchManager.denyPermission()
                UserDefaults.standard.set(true, forKey: "universalSearchPermissionAsked")
            }
        } message: {
            Text("Would you like to enable universal search? This allows Searchfast to find files, documents, applications, and everything on your Mac - just like Raycast! Search for anything, anywhere.")
        }
        .alert("Global Hotkey Setup", isPresented: $showingHotkeyInstructions) {
            Button("Open Settings") {
                openAccessibilitySettings()
            }
            Button("Later", role: .cancel) {
                UserDefaults.standard.set(true, forKey: "hotkeyInstructionsShown")
            }
        } message: {
            Text("🚀 Press Cmd+Shift+Space from anywhere to open Searchfast!\n\nFor global access, please grant Accessibility permissions:\n\n1. Click 'Open Settings' below\n2. Find 'Searchfast' in the list\n3. Toggle it ON\n\nThis allows the hotkey to work when other apps are focused.")
        }
    }
    
    // 🎉 NEW: Check onboarding status on app appear
    private func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("🔍 Checking onboarding status: hasCompleted = \(hasCompletedOnboarding)")
        
        // If user has completed onboarding but is not authenticated, show onboarding again for auth
        if hasCompletedOnboarding && firebaseManager.requireAuthentication() {
            print("🔐 User completed onboarding but not authenticated - showing onboarding for auth")
            hasCompletedOnboarding = false
            showingOnboarding = true
        }
        
        // Note: First launch onboarding is now handled by WindowManager via notification
        // This method just sets the initial state
    }
    
    // 🐱 DEBUG: Method to test first launch (remove this in production)
    private func simulateFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hotkeyInstructionsShown")
        hasCompletedOnboarding = false
        showingOnboarding = true
        windowManager.showOnboardingWindow()
        print("🎯 DEBUG: Simulated first launch - onboarding should show")
    }

    private func captureScreenshot() {
        print("📸 CAPTURING MANUAL SCREENSHOT - SAVING DOGS & CATS!")
        
        isCapturingScreenshot = true
        
        Task {
            if let screenshot = await screenshotManager.captureManual(hideWindow: true) {
                await MainActor.run {
                    withAnimation {
                        self.selectedImage = screenshot
                    }
                    isCapturingScreenshot = false
                    print("✅ MANUAL SCREENSHOT CAPTURED & ATTACHED! Dogs & Cats SAVED!")
                    
                    // Auto-focus search field for immediate interaction
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                    }
                }
            } else {
                await MainActor.run {
                    isCapturingScreenshot = false
                    
                    // Show error to user
                    let alert = NSAlert()
                    alert.messageText = "Screenshot Permission Required"
                    alert.informativeText = "Please grant Screen Recording permission in System Preferences > Security & Privacy > Screen Recording to enable screenshot capture."
                    alert.addButton(withTitle: "Open Settings")
                    alert.addButton(withTitle: "Cancel")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        // Open Screen Recording settings
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private func generateResponse() {
        guard !searchText.isEmpty || selectedImage != nil || autoScreenshot != nil else { return }
        
        // Check if we need to ask for permission first (only once)
        if memoryManager.shouldAskPermission() {
            memoryManager.requestPermission()
            return
        }
        
        let userInput = searchText
        
        // Reset action buttons state
        showingActionButtons = false
        pendingActions = []
        
        // Check if this is an app launch/automation request
        if isAppLaunchRequest(userInput) {
            handleAppLaunchRequest(userInput)
            return
        }
        
        isLoading = true
        response = ""
        responseText = ""
        
        let hasImage = selectedImage != nil

        Task {
            // Capture current context before generating response
            await contextManager.captureCurrentContext()
            
            do {
                let result: GenerateContentResponse
                
                // Load recent memory for context (reduced from 5 to 3)
                let memoryContext = memoryManager.loadRecentMemory(limit: 3)
                
                // 🚀 ENHANCED: Get contextual prompt with screenshot awareness
                let hasScreenshotContext = autoScreenshot != nil || selectedImage != nil
                let contextualPrompt = contextManager.getContextualPrompt(for: userInput, includeScreenshotContext: hasScreenshotContext)
                let fullPrompt = memoryContext.isEmpty ? contextualPrompt : "\(memoryContext)\n\n\(contextualPrompt)"
                
                // 🖼️ SMART IMAGE HANDLING: Use auto-screenshot if available, otherwise manual screenshot
                let imageToUse = selectedImage ?? autoScreenshot
                
                if let image = imageToUse {
                    // Convert NSImage to Data
                    guard let tiffData = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiffData),
                          let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
                        throw NSError(domain: "ImageConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
                    }
                    
                    let prompt = userInput.isEmpty ?
                        "🚀 I can see your screen! What would you like help with? I can analyze what you're working on and provide specific assistance." :
                        fullPrompt
                    
                    let imagePart = ModelContent.Part.data(mimetype: "image/jpeg", jpegData)
                    result = try await model.generateContent(prompt, imagePart)
                    
                    withAnimation {
                        // Clear manual screenshot after sending, but keep auto-screenshot for this session
                        if selectedImage != nil {
                            self.selectedImage = nil
                        }
                    }
                } else {
                    result = try await model.generateContent(fullPrompt)
                }
                
                let resultText = result.text ?? "No response found"
                response = LocalizedStringKey(resultText)
                responseText = resultText
                
                // 🚀 NEW: Parse response for smart action buttons (Cursor-inspired)
                parseResponseForActions(resultText)
                
                // 🎯 SMART BUTTON DETECTION - Always show button for supported apps!
                // Don't rely on keywords - if we can write to the app, show the button!
                if let context = contextManager.currentContext, context.canWriteIntoApp {
                    shouldWriteToApp = true
                    print("✅ SHOWING WRITE BUTTON for \(context.appName) - No keywords needed!")
                } else {
                    shouldWriteToApp = false
                    print("❌ No valid app context for writing")
                }
                
                // Save conversation to memory
                memoryManager.saveConversation(
                    userInput: userInput,
                    aiResponse: resultText,
                    hasImage: hasImage
                )
                
                // Log search query to Firebase (if authenticated)
                Task {
                    await firebaseManager.logSearchQuery(userInput)
                }
                
                searchText = ""
            } catch {
                let errorText = "Something went wrong! \n\(error.localizedDescription)"
                response = LocalizedStringKey(errorText)
                responseText = errorText
                
                // Save error to memory too
                memoryManager.saveConversation(
                    userInput: userInput,
                    aiResponse: errorText,
                    hasImage: hasImage
                )
            }
            isLoading = false
        }
    }
    
    private func copyResponse() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(responseText, forType: .string)
        
        // Show copied state
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        // Reset to copy icon after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
    
    private func handleImageDrop(_ image: NSImage) {
        withAnimation {
            self.selectedImage = image
        }
        // Auto-focus the search field when image is dropped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
        }
    }
    
    private func checkAndShowHotkeyInstructions() {
        let hasShownInstructions = UserDefaults.standard.bool(forKey: "hotkeyInstructionsShown")
        if !hasShownInstructions {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showingHotkeyInstructions = true
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        UserDefaults.standard.set(true, forKey: "hotkeyInstructionsShown")
    }
    
    // 🚀 NEW: Proactive intelligent greeting based on context
    private func showProactiveGreeting() {
        // Only show if we have context and auto-screenshot
        guard let context = contextManager.currentContext,
              autoScreenshot != nil,
              !context.appName.lowercased().contains("searchfast") else {
            return
        }
        
        let proactiveGreeting = generateProactiveGreeting(for: context)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                self.response = LocalizedStringKey(proactiveGreeting)
                self.responseText = proactiveGreeting
                self.showingProactiveGreeting = true
                
                // Parse for suggested actions immediately
                self.parseResponseForActions(proactiveGreeting)
            }
        }
    }
    
    private func generateProactiveGreeting(for context: ContextManager.UserContext) -> String {
        let appName = context.appName
        let activity = context.detectedActivity
        
        // Generate context-aware suggestions
        switch appName.lowercased() {
        case let app where app.contains("adobe") && app.contains("illustrator"):
            return """
            🎨 I can see you're working in Adobe Illustrator! Here are some things I can help with:
            
            • Explain design techniques and effects
            • Help with vector artwork creation
            • Suggest color schemes and typography
            • Guide you through complex tool usage
            • Answer questions about what's currently on your screen
            
            What would you like to work on?
            """
            
        case let app where app.contains("adobe") && app.contains("photoshop"):
            return """
            📸 Working in Photoshop! I can help you with:
            
            • Photo editing techniques and effects
            • Layer management and blending modes
            • Color correction and retouching
            • Creating custom brushes and actions
            • Analyzing your current composition
            
            What's your creative goal today?
            """
            
        case let app where app.contains("figma"):
            return """
            🎯 I see you're designing in Figma! I can assist with:
            
            • UI/UX design best practices
            • Component and prototype creation
            • Design system organization
            • Accessibility considerations
            • Reviewing your current design
            
            How can I enhance your design workflow?
            """
            
        case let app where app.contains("cursor") || app.contains("vs code") || app.contains("xcode"):
            return """
            💻 Coding mode detected! I can help you with:
            
            • Code review and debugging
            • Implementation suggestions
            • Best practices and patterns
            • Documentation and comments
            • Analyzing your current code
            
            What are you building?
            """
            
        case let app where app.contains("word") || app.contains("pages"):
            return """
            📝 Writing in \(appName)! I can help with:
            
            • Content editing and improvement
            • Grammar and style suggestions
            • Document formatting
            • Research and fact-checking
            • Reviewing your current text
            
            What's your writing project about?
            """
            
        case let app where app.contains("excel") || app.contains("numbers"):
            return """
            📊 Working with spreadsheets! I can assist with:
            
            • Formula creation and debugging
            • Data analysis and visualization
            • Chart and graph suggestions
            • Spreadsheet organization
            • Analyzing your current data
            
            What insights are you looking for?
            """
            
        default:
            return """
            🚀 I can see you're working in \(appName) and I've captured your screen for context! 
            
            I can help with:
            • Explaining what I see on your screen
            • Providing app-specific guidance
            • Suggesting next steps for your work
            • Automating repetitive tasks
            
            What would you like to accomplish?
            """
        }
    }
    
    // MARK: - Universal Search Methods
    
    private func search() async {
        handleSearch()

        // Wait for AI response to complete
        while isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }

    private func handleSearch() {
        print("🚀 ENTER PRESSED - CURSOR-INSPIRED INTERACTION! Saving cats & dogs!")
        
        // 🔍 FORCE CONTEXT CAPTURE TO ENSURE WE HAVE THE RIGHT CONTEXT!
        Task {
            await contextManager.captureCurrentContext()
        }
        
        // Clear any universal search results when user explicitly presses Enter
        showingUniversalResults = false
        universalSearchManager.searchResults = []
        
        // 🎯 DEBUG: Print current context details
        if let context = contextManager.currentContext {
            print("📊 CURRENT CONTEXT DEBUG:")
            print("   - App Name: '\(context.appName)'")
            print("   - App Name (lowercase): '\(context.appName.lowercased())'")
            print("   - Window Title: '\(context.windowTitle)'")
            print("   - Can Write Into App: \(context.canWriteIntoApp)")
            print("   - Detected Activity: '\(context.detectedActivity)'")
        } else {
            print("❌ NO CURRENT CONTEXT FOUND!")
        }
        
        // 🚀 NEW CURSOR-INSPIRED FLOW: ALWAYS show response first with action buttons
        // Never hide the window immediately - let user see the response and choose actions
        print("🎯 CURSOR-INSPIRED: Showing AI response FIRST with action buttons!")
        generateResponse()
    }
    
    private func handleUniversalSearchTextChange(_ newValue: String) {
        print("🔍 Universal search text changed to: '\(newValue)'")
        
        // Real-time universal search as user types (optimized debouncing)
        if universalSearchManager.hasPermission && !newValue.isEmpty && newValue.count > 2 { // Only search after 3 chars
            // Increased debouncing to reduce CPU load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Increased from 0.3 to 0.5
                // Only search if the text hasn't changed and is long enough
                if newValue == self.searchText && !self.searchText.isEmpty && self.searchText.count > 2 {
                    self.universalSearchManager.search(query: self.searchText)
                }
            }
            showingUniversalResults = true
        } else {
            showingUniversalResults = false
            universalSearchManager.searchResults = []
        }
    }
    
    private func handleUniversalResultSelection(_ result: UniversalSearchResult) {
        // Open the selected file/app
        universalSearchManager.openFile(result)
        
        // Clear search and hide window
        searchText = ""
        showingUniversalResults = false
        universalSearchManager.searchResults = []
        
        // Hide the window after opening file
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
        }
    }
    
    // MARK: - Smart Writing Detection
    
    private func isWritingRequest(_ userInput: String) -> Bool {
        let writingKeywords = [
            "write", "help me write", "compose", "draft", "create",
            "generate text", "continue writing", "expand on",
            "rewrite", "improve", "summarize", "explain",
            "respond to", "reply", "email", "letter", "document",
            "paragraph", "essay", "article", "blog", "content",
            "type", "insert", "add text", "fill in", "complete"
        ]
        
        let inputLower = userInput.lowercased()
        let isWritingKeyword = writingKeywords.contains { inputLower.contains($0) }
        
        // Always show write button if we have a valid context (unless app is Searchfast)
        let hasValidContext = contextManager.currentContext?.appName != "Searchfast" &&
                             contextManager.currentContext?.canWriteIntoApp == true
        
        print("🔍 Writing request check: '\(userInput)'")
        print("   - Has writing keyword: \(isWritingKeyword)")
        print("   - Has valid context: \(hasValidContext)")
        print("   - Current app: \(contextManager.currentContext?.appName ?? "None")")
        print("   - Can write: \(contextManager.currentContext?.canWriteIntoApp ?? false)")
        
        return isWritingKeyword || hasValidContext
    }
    
    private func writeToCurrentApp() {
        guard let context = contextManager.currentContext else {
            print("❌ No current context for writing")
            shouldWriteToApp = false
            return
        }
        
        let appName = context.appName.lowercased()
        
        // 🐱 CAT-SAVING STRATEGY: NEVER hide search window until AFTER successful automation!
        Task {
            print("📝 🐱 Starting CAT-SAVING automation for \(context.appName)")
            print("🎯 CRITICAL: Keeping search window visible to maintain focus chain")
            
            // Use app-specific advanced automation with clean content extraction
            let success = await automationManager.automateWriting(text: responseText, targetApp: context.appName)
            
            await MainActor.run {
                shouldWriteToApp = false
                
                if success {
                    print("✅ 🐱 CATS SAVED! Successfully wrote to \(context.appName)")
                    // ONLY hide search window AFTER successful automation
                    if let windowManager = NSApp.delegate as? WindowManager {
                        windowManager.hideWindow()
                    }
                } else {
                    print("❌ Automation failed for \(context.appName) - keeping search window visible")
                    // Keep window visible if automation failed
                }
            }
        }
    }
    
    private func handleWordAutoWrite() {
        // Set loading state immediately
        isLoading = true
        response = ""
        responseText = ""
        
        // Hide search window immediately when user presses enter for Word
                if let windowManager = NSApp.delegate as? WindowManager {
                    windowManager.hideWindow()
                }
        
        Task {
            do {
                // Get contextual prompt for better responses
                let contextualPrompt = contextManager.getContextualPrompt(for: searchText)
                
                // Generate AI response
                print("🤖 Generating AI response for Word...")
                let prompt = """
                Please provide a clear, well-structured response to the user's request. 
                Focus on delivering clean, professional content suitable for a Microsoft Word document.
                Avoid unnecessary explanations or meta-commentary.
                
                \(contextualPrompt)
                """
                
                let result = try await model.generateContent(prompt)
                
                if let text = result.text {
                    let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run {
                        response = LocalizedStringKey(cleanText)
                        responseText = cleanText
                        isLoading = false
                    }
                    
                    // Automatically write to Word using the advanced automation
                    print("📝 Auto-writing to Microsoft Word...")
                    let success = await automationManager.automateWriting(text: cleanText, targetApp: "Microsoft Word")
                    
                    await MainActor.run {
                        if success {
                            print("✅ Successfully auto-wrote to Microsoft Word!")
                        } else {
                            print("❌ Failed to auto-write to Microsoft Word")
                            // Show window again if writing failed
                            if let windowManager = NSApp.delegate as? WindowManager {
                                windowManager.forceShowWindow()
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        response = "Sorry, I couldn't generate a response."
                        responseText = "Sorry, I couldn't generate a response."
                        isLoading = false
                        
                        // Show window again if generation failed
                        if let windowManager = NSApp.delegate as? WindowManager {
                            windowManager.forceShowWindow()
                        }
                    }
                }
                
                // Clear search text after processing
                await MainActor.run {
                    searchText = ""
                }
                
            } catch {
                print("❌ Error in Word auto-write: \(error)")
                
                await MainActor.run {
                    response = "Sorry, there was an error generating the response."
                    responseText = "Sorry, there was an error generating the response."
                    isLoading = false
                    
                    // Show window again if there was an error
                    if let windowManager = NSApp.delegate as? WindowManager {
                        windowManager.forceShowWindow()
                    }
                }
            }
        }
    }
    
    // MARK: - MINIMIZED Auto-Write Functions (Window already hidden)
    
    private func handleCursorAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Cursor", appType: .codeEditor, prompt: """
        Please provide clean, executable code for the user's request. 
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handleWordAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Microsoft Word", appType: .document, prompt: """
        Please provide a clear, well-structured response to the user's request. 
        Focus on delivering clean, professional content suitable for a Microsoft Word document.
        Avoid unnecessary explanations or meta-commentary.
        """)
    }
    
    private func handleExcelAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Microsoft Excel", appType: .spreadsheet, prompt: """
        Please provide clear, structured content suitable for Microsoft Excel.
        Focus on delivering data, formulas, or content that works well in spreadsheets.
        Avoid unnecessary explanations.
        """)
    }
    
    private func handleVSCodeAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Visual Studio Code", appType: .codeEditor, prompt: """
        Please provide clean, executable code for the user's request.
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handleXcodeAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Xcode", appType: .codeEditor, prompt: """
        Please provide clean, executable Swift/Objective-C code for the user's request.
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handlePagesAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Pages", appType: .document, prompt: """
        Please provide clear, well-structured content suitable for Apple Pages.
        Focus on delivering clean, professional content without unnecessary explanations.
        """)
    }
    
    private func handleKeynoteAutoWriteMinimized() {
        handleAutoWriteForAppMinimized(appName: "Keynote", appType: .presentation, prompt: """
        Please provide clear, concise content suitable for Keynote presentations.
        Focus on bullet points, short phrases, or slide content.
        Avoid lengthy explanations.
        """)
    }
    
    private func handleGenericAppAutoWriteMinimized(appName: String) {
        handleAutoWriteForAppMinimized(appName: appName, appType: .generic, prompt: """
        Please provide clear, well-structured content for the user's request.
        Focus on delivering clean content without unnecessary explanations.
        """)
    }
    
    // MARK: - LEGACY Auto-Write Functions (for button clicks - these hide window)
    
    private func handleCursorAutoWrite() {
        handleAutoWriteForApp(appName: "Cursor", appType: .codeEditor, prompt: """
        Please provide clean, executable code for the user's request. 
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handleExcelAutoWrite() {
        handleAutoWriteForApp(appName: "Microsoft Excel", appType: .spreadsheet, prompt: """
        Please provide clear, structured content suitable for Microsoft Excel.
        Focus on delivering data, formulas, or content that works well in spreadsheets.
        Avoid unnecessary explanations.
        """)
    }
    
    private func handleVSCodeAutoWrite() {
        handleAutoWriteForApp(appName: "Visual Studio Code", appType: .codeEditor, prompt: """
        Please provide clean, executable code for the user's request.
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handleXcodeAutoWrite() {
        handleAutoWriteForApp(appName: "Xcode", appType: .codeEditor, prompt: """
        Please provide clean, executable Swift/Objective-C code for the user's request.
        Focus on delivering only the code without explanations.
        """)
    }
    
    private func handlePagesAutoWrite() {
        handleAutoWriteForApp(appName: "Pages", appType: .document, prompt: """
        Please provide clear, well-structured content suitable for Apple Pages.
        Focus on delivering clean, professional content without unnecessary explanations.
        """)
    }
    
    private func handleKeynoteAutoWrite() {
        handleAutoWriteForApp(appName: "Keynote", appType: .presentation, prompt: """
        Please provide clear, concise content suitable for Keynote presentations.
        Focus on bullet points, short phrases, or slide content.
        Avoid lengthy explanations.
        """)
    }
    
    private func handleGenericAppAutoWrite(appName: String) {
        handleAutoWriteForApp(appName: appName, appType: .generic, prompt: """
        Please provide clear, well-structured content for the user's request.
        Focus on delivering clean content without unnecessary explanations.
        """)
    }
    
    enum AppType {
        case codeEditor
        case document
        case spreadsheet
        case presentation
        case generic
    }
    
    private func handleAutoWriteForAppMinimized(appName: String, appType: AppType, prompt: String) {
        // Set loading state immediately
        isLoading = true
        response = ""
        responseText = ""
        
        // 📱 WINDOW ALREADY MINIMIZED! Don't hide again.
        print("📱 Window already minimized - proceeding with generation and writing...")
        
        Task {
            do {
                // Get contextual prompt for better responses
                let contextualPrompt = contextManager.getContextualPrompt(for: searchText)
                
                // Generate AI response
                print("🤖 Generating AI response for \(appName)...")
                let fullPrompt = """
                \(prompt)
                
                \(contextualPrompt)
                """
                
                let result = try await model.generateContent(fullPrompt)
                
                if let text = result.text {
                    let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run {
                        response = LocalizedStringKey(cleanText)
                        responseText = cleanText
                        isLoading = false
                    }
                    
                    // Automatically write to the target app using the advanced automation
                    print("📝 Auto-writing to \(appName)...")
                    let success = await automationManager.automateWriting(text: cleanText, targetApp: appName)
                    
                    await MainActor.run {
                        if success {
                            print("✅ Successfully auto-wrote to \(appName)!")
                        } else {
                            print("❌ Failed to auto-write to \(appName)")
                            // Show window again if writing failed
                            if let windowManager = NSApp.delegate as? WindowManager {
                                windowManager.showWindow()
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        response = "Sorry, I couldn't generate a response."
                        responseText = "Sorry, I couldn't generate a response."
                        isLoading = false
                        
                        // Show window again if generation failed
                        if let windowManager = NSApp.delegate as? WindowManager {
                            windowManager.showWindow()
                        }
                    }
                }
                
                // Clear search text after processing
                await MainActor.run {
                    searchText = ""
                }
                
            } catch {
                print("❌ Error in auto-write: \(error)")
                
                await MainActor.run {
                    response = "Sorry, there was an error generating the response."
                    responseText = "Sorry, there was an error generating the response."
                    isLoading = false
                    
                    // Show window again if there was an error
                    if let windowManager = NSApp.delegate as? WindowManager {
                        windowManager.showWindow()
                    }
                }
            }
        }
    }
    
    private func handleAutoWriteForApp(appName: String, appType: AppType, prompt: String) {
        // Set loading state immediately
        isLoading = true
        response = ""
        responseText = ""
        
        // Hide search window immediately when user presses enter
        if let windowManager = NSApp.delegate as? WindowManager {
            windowManager.hideWindow()
        }
        
        Task {
            do {
                // Get contextual prompt for better responses
                let contextualPrompt = contextManager.getContextualPrompt(for: searchText)
                
                // Generate AI response
                print("🤖 Generating AI response for \(appName)...")
                let fullPrompt = """
                \(prompt)
                
                \(contextualPrompt)
                """
                
                let result = try await model.generateContent(fullPrompt)
                
                if let text = result.text {
                    let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run {
                        response = LocalizedStringKey(cleanText)
                        responseText = cleanText
                        isLoading = false
                    }
                    
                    // Automatically write to the target app using the advanced automation
                    print("📝 Auto-writing to \(appName)...")
                    let success = await automationManager.automateWriting(text: cleanText, targetApp: appName)
                    
                    await MainActor.run {
                        if success {
                            print("✅ Successfully auto-wrote to \(appName)!")
                        } else {
                            print("❌ Failed to auto-write to \(appName)")
                            // Show window again if writing failed
                            if let windowManager = NSApp.delegate as? WindowManager {
                                windowManager.forceShowWindow()
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        response = "Sorry, I couldn't generate a response."
                        responseText = "Sorry, I couldn't generate a response."
                        isLoading = false
                        
                        // Show window again if generation failed
                        if let windowManager = NSApp.delegate as? WindowManager {
                            windowManager.forceShowWindow()
                        }
                    }
                }
                
                // Clear search text after processing
                await MainActor.run {
                    searchText = ""
                }
                
            } catch {
                print("❌ Error in auto-write: \(error)")
                
                await MainActor.run {
                    response = "Sorry, there was an error generating the response."
                    responseText = "Sorry, there was an error generating the response."
                    isLoading = false
                    
                    // Show window again if there was an error
                    if let windowManager = NSApp.delegate as? WindowManager {
                        windowManager.forceShowWindow()
                    }
                }
            }
        }
    }
    
    // MARK: - App Launch Detection & Handling
    
    private func isAppLaunchRequest(_ userInput: String) -> Bool {
        let inputLower = userInput.lowercased()
        let launchKeywords = ["open", "launch", "start", "run", "search"]
        let appKeywords = ["safari", "chrome", "google chrome", "firefox", "word", "excel", "powerpoint", "pages", "numbers", "keynote", "xcode", "vs code", "visual studio", "cursor", "slack", "discord", "spotify", "finder", "mail", "messages", "facetime", "zoom", "teams"]
        let hasLaunchKeyword = launchKeywords.contains { inputLower.contains($0) }
        let hasAppKeyword = appKeywords.contains { inputLower.contains($0) }
        // Also catch 'search ... on chrome' and similar
        let matchesSearchOnApp = inputLower.range(of: #"search (.+) on (chrome|google chrome|safari|firefox)"#, options: .regularExpression) != nil
        return (hasLaunchKeyword && hasAppKeyword) || matchesSearchOnApp
    }
    
    private func handleAppLaunchRequest(_ userInput: String) {
        let inputLower = userInput.lowercased()
        var appToLaunch: String?
        var additionalAction: String?
        let appMappings: [String: (name: String, bundleId: String)] = [
            "safari": ("Safari", "com.apple.Safari"),
            "chrome": ("Google Chrome", "com.google.Chrome"),
            "google chrome": ("Google Chrome", "com.google.Chrome"),
            "firefox": ("Firefox", "org.mozilla.firefox"),
            "word": ("Microsoft Word", "com.microsoft.Word"),
            "excel": ("Microsoft Excel", "com.microsoft.Excel"),
            "powerpoint": ("Microsoft PowerPoint", "com.microsoft.PowerPoint"),
            "pages": ("Pages", "com.apple.iWork.Pages"),
            "numbers": ("Numbers", "com.apple.iWork.Numbers"),
            "keynote": ("Keynote", "com.apple.iWork.Keynote"),
            "xcode": ("Xcode", "com.apple.dt.Xcode"),
            "vs code": ("Visual Studio Code", "com.microsoft.VSCode"),
            "visual studio": ("Visual Studio Code", "com.microsoft.VSCode"),
            "cursor": ("Cursor", "com.todesktop.230313mzl4w4u92"),
            "slack": ("Slack", "com.tinyspeck.slackmacgap"),
            "discord": ("Discord", "com.hnc.Discord"),
            "spotify": ("Spotify", "com.spotify.client"),
            "finder": ("Finder", "com.apple.finder"),
            "mail": ("Mail", "com.apple.mail"),
            "messages": ("Messages", "com.apple.MobileSMS"),
            "facetime": ("FaceTime", "com.apple.FaceTime"),
            "zoom": ("zoom.us", "us.zoom.xos"),
            "teams": ("Microsoft Teams", "com.microsoft.teams")
        ]
        // 1. Check for 'search ... on chrome' pattern
        if let match = inputLower.range(of: #"search (.+) on (chrome|google chrome|safari|firefox)"#, options: .regularExpression) {
            let matchedString = String(inputLower[match])
            let regex = try! NSRegularExpression(pattern: #"search (.+) on (chrome|google chrome|safari|firefox)"#)
            if let result = regex.firstMatch(in: matchedString, options: [], range: NSRange(location: 0, length: matchedString.utf16.count)),
               let searchRange = Range(result.range(at: 1), in: matchedString),
               let appRange = Range(result.range(at: 2), in: matchedString) {
                let searchTerm = String(matchedString[searchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let appName = String(matchedString[appRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                appToLaunch = appMappings[appName]?.name ?? appName.capitalized
                // Build Google search URL
                let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
                additionalAction = "https://www.google.com/search?q=\(encoded)"
            }
        } else {
            // Fallback: original logic
            for (keyword, app) in appMappings {
                if inputLower.contains(keyword) {
                    appToLaunch = app.name
                    break
                }
            }
            // Check for additional actions (like "search yahoo")
            if inputLower.contains("search") {
                let words = inputLower.components(separatedBy: " ")
                if let idx = words.firstIndex(of: "search"), words.count > idx + 1 {
                    let searchTerm = words[(idx+1)...].joined(separator: " ")
                    let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
                    additionalAction = "https://www.google.com/search?q=\(encoded)"
                }
            }
            // Check for direct URL navigation
            if inputLower.contains("go to") || inputLower.contains("visit") || inputLower.contains("open") {
                if inputLower.contains("youtube") {
                    additionalAction = "https://www.youtube.com"
                } else if inputLower.contains("github") {
                    additionalAction = "https://github.com"
                } else if inputLower.contains("stackoverflow") || inputLower.contains("stack overflow") {
                    additionalAction = "https://stackoverflow.com"
                } else if inputLower.contains("reddit") {
                    additionalAction = "https://www.reddit.com"
                } else if inputLower.contains("twitter") {
                    additionalAction = "https://twitter.com"
                } else if inputLower.contains("facebook") {
                    additionalAction = "https://www.facebook.com"
                } else if inputLower.contains("instagram") {
                    additionalAction = "https://www.instagram.com"
                } else if inputLower.contains("linkedin") {
                    additionalAction = "https://www.linkedin.com"
                }
            }
        }
        executeAppLaunch(appName: appToLaunch, action: additionalAction, originalRequest: userInput)
    }
    
    private func executeAppLaunch(appName: String?, action: String?, originalRequest: String) {
        Task {
            isLoading = true
            do {
                if let appName = appName {
                    // Launch the app
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: getBundleId(for: appName)) ?? findAppByName(appName) {
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = true
                        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                        // Wait for app to launch (retry up to 3s)
                        var launched = false
                        for _ in 0..<6 {
                            if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == getBundleId(for: appName) }) {
                                launched = true
                                break
                            }
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        }
                        if !launched {
                            response = LocalizedStringKey("❌ Could not launch \(appName). Is it installed?")
                            responseText = "❌ Could not launch \(appName). Is it installed?"
                            isLoading = false
                            return
                        }
                        // If there's an additional action (like opening a URL), open it in the specific app
                        if let action = action, let url = URL(string: action) {
                            await openURLInSpecificApp(url: url, appName: appName)
                        }
                        let actionDescription = action != nil ? " and navigated to \(action!)" : ""
                        response = LocalizedStringKey("✅ Launched \(appName)\(actionDescription)")
                        responseText = "✅ Launched \(appName)\(actionDescription)"
                    } else {
                        response = LocalizedStringKey("❌ Could not find \(appName). Please make sure it's installed.")
                        responseText = "❌ Could not find \(appName). Please make sure it's installed."
                        isLoading = false
                        return
                    }
                } else {
                    response = LocalizedStringKey("❌ Could not identify which app to launch from: \(originalRequest)")
                    responseText = "❌ Could not identify which app to launch from: \(originalRequest)"
                    isLoading = false
                    return
                }
                searchText = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if let windowManager = NSApp.delegate as? WindowManager {
                        windowManager.hideWindow()
                    }
                }
            } catch {
                response = LocalizedStringKey("❌ Failed to launch app: \(error.localizedDescription)")
                responseText = "❌ Failed to launch app: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func getBundleId(for appName: String) -> String {
        let bundleIds: [String: String] = [
            "Safari": "com.apple.Safari",
            "Google Chrome": "com.google.Chrome",
            "Firefox": "org.mozilla.firefox",
            "Microsoft Word": "com.microsoft.Word",
            "Microsoft Excel": "com.microsoft.Excel",
            "Microsoft PowerPoint": "com.microsoft.PowerPoint",
            "Pages": "com.apple.iWork.Pages",
            "Numbers": "com.apple.iWork.Numbers",
            "Keynote": "com.apple.iWork.Keynote",
            "Xcode": "com.apple.dt.Xcode",
            "Visual Studio Code": "com.microsoft.VSCode",
            "Cursor": "com.todesktop.230313mzl4w4u92",
            "Slack": "com.tinyspeck.slackmacgap",
            "Discord": "com.hnc.Discord",
            "Spotify": "com.spotify.client",
            "Finder": "com.apple.finder",
            "Mail": "com.apple.mail",
            "Messages": "com.apple.MobileSMS",
            "FaceTime": "com.apple.FaceTime",
            "zoom.us": "us.zoom.xos",
            "Microsoft Teams": "com.microsoft.teams"
        ]
        
        return bundleIds[appName] ?? ""
    }
    
    private func findAppByName(_ appName: String) -> URL? {
        let appName = appName.lowercased()
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        
        do {
            let apps = try FileManager.default.contentsOfDirectory(at: applicationsURL, includingPropertiesForKeys: nil)
            for app in apps {
                if app.lastPathComponent.lowercased().contains(appName) {
                    return app
                }
            }
        } catch {
            print("Error searching for app: \(error)")
        }
        
        return nil
    }
    
    private func openURLInSpecificApp(url: URL, appName: String) async {
        let bundleId = getBundleId(for: appName)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            if !bundleId.isEmpty, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
            } else {
                await openURLWithAppleScript(url: url.absoluteString, appName: appName)
            }
        } catch {
            print("Failed to open URL in \(appName): \(error)")
            response = LocalizedStringKey("❌ Failed to open URL in \(appName): \(error.localizedDescription)")
            responseText = "❌ Failed to open URL in \(appName): \(error.localizedDescription)"
            await openURLWithAppleScript(url: url.absoluteString, appName: appName)
        }
    }
    
    private func openURLWithAppleScript(url: String, appName: String) async {
        let escapedURL = url.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch appName.lowercased() {
        case let app where app.contains("safari"):
            script = """
                tell application \"Safari\"
                    activate
                    delay 0.3
                    open location \"\(escapedURL)\"
                end tell
            """
        case let app where app.contains("chrome"):
            script = """
                tell application \"Google Chrome\"
                    activate
                    delay 0.3
                    open location \"\(escapedURL)\"
                end tell
            """
        case let app where app.contains("firefox"):
            script = """
                tell application \"Firefox\"
                    activate
                    delay 0.3
                    open location \"\(escapedURL)\"
                end tell
            """
        default:
            script = """
                tell application \"\(escapedAppName)\"
                    activate
                    delay 0.3
                    open location \"\(escapedURL)\"
                end tell
            """
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ AppleScript error opening URL: \(error)")
                        response = LocalizedStringKey("❌ AppleScript error opening URL: \(error)")
                        responseText = "❌ AppleScript error opening URL: \(error)"
                    } else {
                        print("✅ Successfully opened \(url) in \(appName)")
                    }
                }
            }
        }
    }
    
    // MARK: - UI Helper Functions
    
    private func getAutomationIcon(for appName: String) -> String {
        let appLower = appName.lowercased()
        
        switch appLower {
        case let app where app.contains("chrome"):
            return "globe"
        case let app where app.contains("safari"):
            return "safari"
        case let app where app.contains("pages"):
            return "doc.text"
        case let app where app.contains("word"):
            return "doc.richtext"
        case let app where app.contains("excel"):
            return "tablecells"
        case let app where app.contains("powerpoint"):
            return "presentation"
        case let app where app.contains("numbers"):
            return "tablecells.fill"
        case let app where app.contains("keynote"):
            return "presentation.fill"
        case let app where app.contains("xcode"):
            return "hammer"
        case let app where app.contains("vs code") || app.contains("visual studio"):
            return "chevron.left.forwardslash.chevron.right"
        case let app where app.contains("cursor"):
            return "curlybraces.square"
        case let app where app.contains("slack"):
            return "message.circle"
        case let app where app.contains("discord"):
            return "message.badge"
        case let app where app.contains("mail"):
            return "envelope"
        case let app where app.contains("messages"):
            return "message"
        case let app where app.contains("notion"):
            return "doc.plaintext"
        case let app where app.contains("zoom"):
            return "video"
        case let app where app.contains("teams"):
            return "video.circle"
        case let app where app.contains("textedit"):
            return "text.alignleft"
        case let app where app.contains("notes"):
            return "note.text"
        default:
            return "pencil.and.ellipsis.rectangle"
        }
    }
    
    private func getAutomationColors(for appName: String) -> [Color] {
        let appLower = appName.lowercased()
        
        switch appLower {
        case let app where app.contains("chrome"):
            return [Color.blue, Color.green]
        case let app where app.contains("safari"):
            return [Color.blue, Color.cyan]
        case let app where app.contains("pages"):
            return [Color.orange, Color.yellow]
        case let app where app.contains("word"):
            return [Color.blue, Color.indigo]
        case let app where app.contains("excel"):
            return [Color.green, Color.teal]
        case let app where app.contains("powerpoint"):
            return [Color.orange, Color.red]
        case let app where app.contains("numbers"):
            return [Color.green, Color.mint]
        case let app where app.contains("keynote"):
            return [Color.orange, Color.pink]
        case let app where app.contains("xcode"):
            return [Color.indigo, Color.purple]
        case let app where app.contains("vs code") || app.contains("visual studio"):
            return [Color.blue, Color.purple]
        case let app where app.contains("cursor"):
            return [Color.cyan, Color.blue]
        case let app where app.contains("slack"):
            return [Color.purple, Color.pink]
        case let app where app.contains("discord"):
            return [Color.indigo, Color.blue]
        case let app where app.contains("mail"):
            return [Color.blue, Color.cyan]
        case let app where app.contains("messages"):
            return [Color.green, Color.blue]
        case let app where app.contains("notion"):
            return [Color.gray, Color.black]
        case let app where app.contains("zoom"):
            return [Color.blue, Color.indigo]
        case let app where app.contains("teams"):
            return [Color.purple, Color.blue]
        case let app where app.contains("textedit"):
            return [Color.gray, Color.blue]
        case let app where app.contains("notes"):
            return [Color.yellow, Color.orange]
        default:
            return [Color.blue, Color.purple]
        }
    }
    
    private func getStrategyDescription(_ strategy: AppAutomationManager.AutomationStrategy) -> String {
        switch strategy {
        case .appleScript:
            return "AppleScript"
        case .accessibility:
            return "Accessibility API"
        case .uiTest:
            return "UI Testing"
        case .hybrid:
            return "Hybrid (Smart)"
        }
    }
    
    // MARK: - 🚀 NEW: Action Button System (Cursor-inspired)
    
    private func getActionIcon(for actionType: ResponseAction.ActionType) -> String {
        switch actionType {
        case .writeToApp:
            return "pencil.and.ellipsis.rectangle"
        case .openApp:
            return "app.badge"
        case .executeScript:
            return "terminal"
        case .copyText:
            return "doc.on.doc"
        case .searchWeb:
            return "magnifyingglass"
        }
    }
    
    private func executeAction(_ action: ResponseAction) {
        print("🚀 EXECUTING ACTION: \(action.title)")
        
        Task { @MainActor in
            switch action.actionType {
            case .writeToApp:
                await executeWriteToAppAction(action.payload)
                
            case .openApp:
                await executeOpenAppAction(action.payload)
                
            case .executeScript:
                await executeScriptAction(action.payload)
                
            case .copyText:
                executeCopyTextAction(action.payload)
                
            case .searchWeb:
                executeSearchWebAction(action.payload)
            }
            
            // Hide action buttons after execution
            withAnimation {
                showingActionButtons = false
                pendingActions = []
            }
        }
    }
    
    private func executeWriteToAppAction(_ text: String) async {
        print("✍️ Writing to app: \(text)")
        await contextManager.writeIntoCurrentApp(text)
        
        // Hide the search window after writing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
        }
    }
    
    private func executeOpenAppAction(_ appName: String) async {
        print("📱 Opening app: \(appName)")
        
        // Use the public searchApps method to find matching apps
        let matchingApps = await MainActor.run {
            appSearchManager.searchApps(query: appName)
        }
        
        if let appToLaunch = matchingApps.first {
            await MainActor.run {
                appSearchManager.launchApp(appToLaunch)
                print("✅ Successfully launched \(appToLaunch.name)")
            }
        } else {
            // Fallback to simple NSWorkspace launch
            do {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: getBundleId(for: appName)) ?? findAppByName(appName) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                    print("✅ Successfully launched \(appName) via fallback")
                } else {
                    print("❌ Could not find \(appName)")
                }
            } catch {
                print("❌ Failed to launch \(appName): \(error)")
            }
        }
        
        // Hide the search window after opening app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
        }
    }
    
    private func executeScriptAction(_ script: String) async {
        print("⚙️ Executing script: \(script)")
        // Implement script execution logic here
        // This could be AppleScript, shell commands, etc.
    }
    
    private func executeCopyTextAction(_ text: String) {
        print("📋 Copying text: \(text)")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Show feedback
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func executeSearchWebAction(_ urlOrQuery: String) {
        print("🔍 Searching web: \(urlOrQuery)")
        
        var finalURL: URL?
        
        // Check if it's already a full URL
        if urlOrQuery.hasPrefix("http") {
            finalURL = URL(string: urlOrQuery)
        } else {
            // Treat as a search query
            finalURL = URL(string: "https://www.google.com/search?q=\(urlOrQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        
        if let url = finalURL {
            NSWorkspace.shared.open(url)
            print("✅ Successfully opened: \(url)")
        } else {
            print("❌ Failed to create URL from: \(urlOrQuery)")
        }
        
        // Hide the search window after opening web search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
        }
    }
    
    // 🤖 AI Response Parser - Detect and create action buttons (CURSOR-INSPIRED)
    private func parseResponseForActions(_ responseText: String) {
        print("🤖 PARSING RESPONSE FOR ACTIONS...")
        
        var actions: [ResponseAction] = []
        
        // 🚀 SMART ACTION DETECTION: If we can write to the current app, ALWAYS show a write button
        if let context = contextManager.currentContext, context.canWriteIntoApp {
            let appName = context.appName
            
            // For code editors, show "Write to Cursor/VS Code/Xcode"
            if appName.lowercased().contains("cursor") {
                actions.append(ResponseAction(
                    title: "Write to Cursor",
                    description: "Insert code into Cursor IDE",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("visual studio code") || appName.lowercased().contains("vs code") {
                actions.append(ResponseAction(
                    title: "Write to VS Code",
                    description: "Insert code into VS Code",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("xcode") {
                actions.append(ResponseAction(
                    title: "Write to Xcode",
                    description: "Insert code into Xcode",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("word") {
                actions.append(ResponseAction(
                    title: "Write to Word",
                    description: "Insert text into Microsoft Word",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("excel") {
                actions.append(ResponseAction(
                    title: "Write to Excel",
                    description: "Insert content into Excel",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("pages") {
                actions.append(ResponseAction(
                    title: "Write to Pages",
                    description: "Insert text into Pages",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else if appName.lowercased().contains("chrome") {
                actions.append(ResponseAction(
                    title: "Write to Chrome",
                    description: "Insert text into current Chrome tab",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            } else {
                // Generic write button for any supported app
                actions.append(ResponseAction(
                    title: "Write to \(appName)",
                    description: "Insert content into \(appName)",
                    actionType: .writeToApp,
                    payload: responseText
                ))
            }
        }
        
        // 🔍 SMART WEB SEARCH DETECTION
        if responseText.lowercased().contains("search") || responseText.lowercased().contains("google") ||
           responseText.lowercased().contains("amazon") || responseText.lowercased().contains("find") {
            
            let searchQuery = extractSearchQuery(from: responseText)
            if !searchQuery.isEmpty {
                // Detect specific search engines
                if responseText.lowercased().contains("amazon") {
                    actions.append(ResponseAction(
                        title: "Search Amazon",
                        description: "Search on Amazon",
                        actionType: .searchWeb,
                        payload: "https://amazon.com/s?k=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    ))
                } else if responseText.lowercased().contains("youtube") {
                    actions.append(ResponseAction(
                        title: "Search YouTube",
                        description: "Search on YouTube",
                        actionType: .searchWeb,
                        payload: "https://youtube.com/results?search_query=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    ))
                } else {
                    actions.append(ResponseAction(
                        title: "Search Google",
                        description: "Search on Google",
                        actionType: .searchWeb,
                        payload: "https://google.com/search?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    ))
                }
            }
        }
        
        // 📱 APP OPENING DETECTION
        let suggestedApp = extractSuggestedApp(from: responseText)
        if !suggestedApp.isEmpty {
            actions.append(ResponseAction(
                title: "Open \(suggestedApp)",
                description: "Launch \(suggestedApp)",
                actionType: .openApp,
                payload: suggestedApp
            ))
        }
        
        // 📋 COPY TEXT DETECTION
        if responseText.count > 10 { // Any meaningful response can be copied
            actions.append(ResponseAction(
                title: "Copy Response",
                description: "Copy full response to clipboard",
                actionType: .copyText,
                payload: responseText
            ))
        }
        
        // Update UI with discovered actions
        DispatchQueue.main.async {
            withAnimation {
                self.pendingActions = actions
                self.showingActionButtons = !actions.isEmpty
            }
        }
        
        print("🎯 DISCOVERED \(actions.count) ACTIONS")
        for action in actions {
            print("   - \(action.title): \(action.description)")
        }
    }
    
    private func extractSuggestedText(from response: String) -> String {
        // Simple text extraction - look for quoted text or code blocks
        let patterns = [
            "\"([^\"]+)\"",  // Text in quotes
            "`([^`]+)`",    // Text in backticks
            "```[\\s\\S]*?```", // Code blocks
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) {
                let matchedString = String(response[Range(match.range, in: response)!])
                return matchedString.trimmingCharacters(in: CharacterSet(charactersIn: "\"`"))
            }
        }
        
        return ""
    }
    
    private func extractSuggestedApp(from response: String) -> String {
        let apps = ["Chrome", "Safari", "Firefox", "Word", "Excel", "PowerPoint", "Pages", "Numbers", "Keynote", "Xcode", "VS Code", "Cursor", "Slack", "Discord", "Mail", "Messages", "Notion", "Zoom", "Teams"]
        
        for app in apps {
            if response.lowercased().contains(app.lowercased()) {
                return app
            }
        }
        
        return ""
    }
    
    private func extractTextToCopy(from response: String) -> String {
        // Extract text that should be copied
        return extractSuggestedText(from: response)
    }
    
    private func extractSearchQuery(from response: String) -> String {
        // Extract search query from the user's original input or response
        // First try to get it from the user's search text
        if !searchText.isEmpty {
            return searchText
        }
        
        // Look for quoted text or specific search patterns
        let patterns = [
            "search for \"([^\"]+)\"",
            "search \"([^\"]+)\"",
            "find \"([^\"]+)\"",
            "look up \"([^\"]+)\"",
            "amazon \"([^\"]+)\"",
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
               match.numberOfRanges > 1 {
                let matchRange = Range(match.range(at: 1), in: response)!
                return String(response[matchRange])
            }
        }
        
        // Fallback: use the first few words if no pattern found
        let words = response.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(3)
        
        return words.joined(separator: " ")
    }
    
    // MARK: - Speech Functions
    
    // MARK: - Speech Recognition Helpers
    
    private func enterSpeechMode() {
        isSpeechMode = true
        if speechManager.isRecording {
            speechManager.stopRecording()
        } else {
            searchText = "" // Clear text for new speech input
            response = "Listening..."
            responseText = "Listening..."
            speechManager.startRecording()
        }
    }
    
    private func exitSpeechMode() {
        if speechManager.isRecording {
            speechManager.stopRecording()
        }
        isSpeechMode = false
    }
    
    @MainActor
    private func processSpeechInput(_ capturedText: String) async {
        // Immediately switch back to the text input UI
        isSpeechMode = false
        // Show the transcribed text in the search bar
        searchText = capturedText
        
        // Now, handle the search and spoken response
        await handleSearchWithSpeechResponse()
    }
    
    private func handleSpeechToggle() {
        if speechManager.isRecording {
            // Manually stop listening
            speechManager.stopRecording()
        } else {
            // Start listening
            enterSpeechMode()
        }
    }
    
    private func cancelSpeechMode() {
        print("🎤 Canceling Speech Mode")

        // Cancel recording first
        speechManager.stopRecording()
        speechManager.recognizedText = ""

        // Exit speech mode with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isSpeechMode = false
        }
        
        // Ensure clean state after cancellation
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await MainActor.run {
                // Double-check that we've exited speech mode completely
                if !isSpeechMode && speechManager.isRecording {
                    speechManager.stopRecording()
                }
            }
        }
    }
    
    private func handleSearchWithSpeechResponse() async {
        // Process the search normally first
        handleSearch()
        
        // Wait for AI response to complete, then speak it
        while isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // Speak the response text
        if !responseText.isEmpty && responseText != "How can I help you today?" {
            // Extract just the main response without action descriptions
            let cleanResponse = extractMainResponse(from: responseText)
            print("🗣️ Speaking AI response: \(cleanResponse)")
            
            // Call TTS on main actor to avoid concurrency issues
            await MainActor.run {
                speechManager.speak(text: cleanResponse)
            }
        }
    }
    
    private func extractMainResponse(from response: String) -> String {
        // Remove markdown formatting and extract the main content
        var cleanResponse = response
        
        // Remove common markdown patterns
        cleanResponse = cleanResponse.replacingOccurrences(of: "**", with: "")
        cleanResponse = cleanResponse.replacingOccurrences(of: "*", with: "")
        cleanResponse = cleanResponse.replacingOccurrences(of: "`", with: "")
        
        // Take only the first paragraph or sentence for speaking
        let sentences = cleanResponse.components(separatedBy: ". ")
        if let firstSentence = sentences.first, firstSentence.count > 10 {
            return firstSentence + (sentences.count > 1 ? "." : "")
        }
        
        // Fallback to first 150 characters
        if cleanResponse.count > 150 {
            let index = cleanResponse.index(cleanResponse.startIndex, offsetBy: 150)
            return String(cleanResponse[..<index]) + "..."
        }
        
        return cleanResponse
    }
    
    // 🎯 EXTRACTED: Main content view for cleaner code organization
    private var mainContentView: some View {
        VStack(spacing: 0) {
            searchSection
            
            if selectedImage != nil || autoScreenshot != nil {
                attachmentSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                    ))
            }
            
            // Show results section if we have search results OR AI response (not default greeting)
            if showingUniversalResults || (!responseText.isEmpty && responseText != "How can I help you today?") {
                resultsSection
            }
            
            if isLoading {
                LoadingIndicator(animation: .threeBallsTriangle, color: .white, size: .medium, speed: .normal)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 0.8))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // REMOVED: .background(Color.clear)
        // REMOVED: .liquidGlassSpotlight()
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingActionButtons)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedImage != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: autoScreenshot != nil)
    }
    
    // Break down into smaller components
    private var searchSection: some View {
        searchInputArea
    }
    
    private var searchInputArea: some View {
        ZStack {
            SearchBar(text: $searchText, onSubmit: handleSearch, onImageDrop: handleImageDrop, contextManager: contextManager)
                .frame(maxWidth: .infinity)
                .onChange(of: searchText) { newValue in
                    handleUniversalSearchTextChange(newValue)
                }
                .opacity(isSpeechMode ? 0 : 1)
                .disabled(isSpeechMode)
            
            if isSpeechMode {
                SpeechAnimationView(speechManager: speechManager, onCancel: cancelSpeechMode)
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        handleSpeechToggle()
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSpeechMode)
    }
    
    private var attachmentSection: some View {
        HStack(spacing: 8) {
            if let selectedImage = selectedImage {
                attachmentIndicator(
                    image: selectedImage,
                    title: "Manual",
                    color: .blue,
                    action: { self.selectedImage = nil }
                )
            }
            
            if let autoScreenshot = autoScreenshot {
                attachmentIndicator(
                    image: autoScreenshot,
                    title: "Auto-captured",
                    color: .green,
                    action: { self.autoScreenshot = nil }
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }
    
    @ViewBuilder
    private func attachmentIndicator(image: NSImage, title: String, color: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.fill")
                .font(.system(size: 8))
                .foregroundColor(color)
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 12, height: 12)
                .cornerRadius(2)
                .clipped()
            
            Text(title)
                .font(.system(size: 7))
                .foregroundColor(color)
            
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .light ? 
                      Color.white.opacity(0.8) : 
                      Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    private var resultsSection: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Always show universal results when they exist and showingUniversalResults is true
                    if showingUniversalResults && !universalSearchManager.searchResults.isEmpty {
                        universalResultsView
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    // Show AI response if it's not the default greeting
                    if !responseText.isEmpty && responseText != "How can I help you today?" {
                        aiResponseView
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private var universalResultsView: some View {
        VStack {
            if !universalSearchManager.searchResults.isEmpty {
                // Use the beautiful Spotlight-style AppSearchResultsView for applications
                if let appResults = universalSearchManager.searchResults.first(where: { $0.category == .applications }),
                   !appResults.results.isEmpty {
                    
                    // Convert UniversalSearchResult to AppInfo for the Spotlight-style view
                    let appInfoResults = appResults.results.map { result in
                        AppInfo(
                            name: result.name,
                            path: result.path,
                            bundleIdentifier: result.bundleIdentifier ?? "",
                            icon: result.icon,
                            version: extractVersionFromPath(result.path)
                        )
                    }
                    
                    AppSearchResultsView(
                        apps: appInfoResults,
                        onAppSelected: { appInfo in
                            // Convert back to UniversalSearchResult for handler
                            if let originalResult = appResults.results.first(where: { $0.path == appInfo.path }) {
                                handleUniversalResultSelection(originalResult)
                            }
                        }
                    )
                    
                } else {
                    // For non-app results, use the original view
                    UniversalSearchResultsView(
                        categoryResults: universalSearchManager.searchResults,
                        onResultSelected: handleUniversalResultSelection
                    )
                }
                
                if !searchText.isEmpty {
                    Button("Ask AI instead: \"\(searchText)\"") {
                        generateResponse()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .liquidGlassActionButton(colors: [.blue, .cyan])
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // Helper function to extract version from app path
    private func extractVersionFromPath(_ path: String) -> String? {
        // Try to get version from bundle info
        if let bundle = Bundle(path: path),
           let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return nil
    }
    
    private var aiResponseView: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Text(response)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .light ? 
                                  Color.white.opacity(0.8) : 
                                  Color.black.opacity(0.4))
                            .shadow(
                                color: colorScheme == .light ? 
                                       Color.black.opacity(0.1) : 
                                       Color.clear, 
                                radius: 8, 
                                x: 0, 
                                y: 2
                            )
                    )
                
                Button(action: copyResponse) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(isCopied ? .green : .primary.opacity(0.7))
                        .font(.system(size: 12, weight: .medium))
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
            
            if showingActionButtons {
                actionButtonsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                    ))
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 8) {
            if shouldWriteToApp, let context = contextManager.currentContext {
                Button(action: writeToCurrentApp) {
                    HStack {
                        if automationManager.isAutomating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: getAutomationIcon(for: context.appName))
                                .font(.system(size: 12))
                        }
                        
                        Text(automationManager.isAutomating ? "Writing..." : "Write to \(context.appName)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: getAutomationColors(for: context.appName)),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.2),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(automationManager.isAutomating)
            }
            
            ForEach(pendingActions) { action in
                Button(action.title) {
                    executeAction(action)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .light ? 
                              Color.white.opacity(0.8) : 
                              Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(
                            color: colorScheme == .light ? 
                                   Color.black.opacity(0.1) : 
                                   Color.clear, 
                            radius: 8, 
                            x: 0, 
                            y: 2
                        )
                )
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
