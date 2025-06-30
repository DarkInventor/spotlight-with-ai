import CoreFoundation
import SwiftUI
import GoogleGenerativeAI
import SwiftfulLoadingIndicators
import ScreenCaptureKit
import CoreMedia

struct ContentView: View {
    @State private var searchText: String = ""
    @State private var response: LocalizedStringKey = "How can I help you today?"
    @State private var responseText: String = "How can I help you today?"
    @State private var isLoading = false
    @State private var isCopied = false
    @State private var selectedImage: NSImage? = nil
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var universalSearchManager = UniversalSearchManager()
    @StateObject private var contextManager = ContextManager()
    @StateObject private var automationManager = AppAutomationManager()
    @State private var showingHotkeyInstructions = false
    @State private var showingUniversalResults = false
    @State private var isCapturingScreenshot = false
    @State private var shouldWriteToApp = false
    @Environment(\.colorScheme) private var colorScheme
    // Before running, please ensure you have added the GoogleGenerativeAI package.
    // In Xcode: File > Add Package Dependencies... > https://github.com/google/generative-ai-swift
    private let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: APIKey.default)

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                // Search bar with screenshot button
                HStack(spacing: 12) {
                    SearchBar(text: $searchText, onSubmit: handleSearch, onImageDrop: handleImageDrop, contextManager: contextManager)
                        .frame(maxWidth: .infinity)
                        .onChange(of: searchText) { newValue in
                            handleUniversalSearchTextChange(newValue)
                        }
                    
                    // Screenshot capture button
                    Button(action: captureScreenshot) {
                        ZStack {
                            Circle()
                                .fill(isCapturingScreenshot ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 46, height: 46)
                                .overlay(
                                    Circle()
                                        .stroke(isCapturingScreenshot ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            if isCapturingScreenshot {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            } else {
                                Image(systemName: selectedImage != nil ? "camera.fill" : "camera")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(selectedImage != nil ? .green : (colorScheme == .light ? .black.opacity(0.5) : .green.opacity(0.5)))
                                    .padding()
                                    .glassEffect()
                                    .onHover { isHovered in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            // You can add hover state management here if needed
                                        }
                                    }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCapturingScreenshot)
                    .help("Capture Screenshot")
                }
                .padding(.horizontal, 20)
                
                if let selectedImage = selectedImage {
                    HStack {
                        // Very small attachment indicator
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .light ? .black.opacity(0.6) : .white.opacity(0.6))
                            
                            Image(nsImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 16, height: 16)
                                .cornerRadius(3)
                                .clipped()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                self.selectedImage = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
            }

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Debug: Show current context and automation capabilities
                        // if let context = contextManager.currentContext {
                        //     VStack(alignment: .leading, spacing: 4) {
                        //         Text("📍 Context: \(context.detectedActivity)")
                        //             .font(.caption)
                        //             .foregroundColor(.secondary)
                        //         Text("🖥️ App: \(context.appName)")
                        //             .font(.caption)
                        //             .foregroundColor(.secondary)
                        //         if !context.windowTitle.isEmpty && context.windowTitle != "Unknown" {
                        //             Text("🪟 Window: \(context.windowTitle)")
                        //                 .font(.caption)
                        //                 .foregroundColor(.secondary)
                        //         }
                                
                        //         // Show automation capability
                        //         HStack {
                        //             if automationManager.canAutomateApp(context.appName) {
                        //                 Image(systemName: "checkmark.circle.fill")
                        //                     .foregroundColor(.green)
                        //                     .font(.caption)
                        //                 Text("Automation supported")
                        //                     .font(.caption)
                        //                     .foregroundColor(.green)
                        //             } else {
                        //                 Image(systemName: "exclamationmark.circle.fill")
                        //                     .foregroundColor(.orange)
                        //                     .font(.caption)
                        //                 Text("Basic automation only")
                        //                     .font(.caption)
                        //                     .foregroundColor(.orange)
                        //             }
                        //         }
                                
                        //         HStack {
                        //             Button("🔄 Refresh Context") {
                        //                 Task {
                        //                     await contextManager.captureCurrentContext()
                        //                 }
                        //             }
                        //             .font(.caption)
                        //             .buttonStyle(.borderless)
                                    
                        //             Button("🤖 Show Supported Apps") {
                        //                 let apps = automationManager.getSupportedApps().joined(separator: ", ")
                        //                 print("🤖 Supported Apps: \(apps)")
                        //             }
                        //             .font(.caption)
                        //             .buttonStyle(.borderless)
                        //         }
                        //     }
                        //     .padding(8)
                        //     .background(Color.secondary.opacity(0.1))
                        //     .cornerRadius(8)
                        // }
                        
                        // Universal search results (shown above AI response when searching)
                        if showingUniversalResults {
                            VStack {
                                if !universalSearchManager.searchResults.isEmpty {
                                    UniversalSearchResultsView(
                                        categoryResults: universalSearchManager.searchResults,
                                        onResultSelected: handleUniversalResultSelection
                                    )
                                    .background(Color.clear)
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .animation(.easeInOut(duration: 0.3), value: universalSearchManager.searchResults.count)
                                    
                                    if !searchText.isEmpty {
                                        Button(action: {
                                            // Continue with AI search instead
                                            generateResponse()
                                        }) {
                                            HStack {
                                                Image(systemName: "brain")
                                                    .font(.system(size: 12))
                                                Text("Ask AI instead: \"\(searchText)\"")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(20)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // AI Response area
                        VStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                Text(response)
                                    .font(.system(size: 16, weight: .regular))
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .padding()
                                    .background(Color.clear)
                                    .glassEffect(in: .rect(cornerRadius: 16.0))
                                    .animation(.easeInOut(duration: 0.3), value: response)
                                
                                Button(action: copyResponse) {
                                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                        .foregroundColor(isCopied ? .green : (colorScheme == .light ? Color.black.opacity(0.7) : Color.white.opacity(0.6)))
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .opacity(responseText == "How can I help you today?" ? 0 : 1)
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                            }
                            
                            // Smart "Write to App" button with automation capabilities
                            if shouldWriteToApp, let context = contextManager.currentContext {
                                VStack(spacing: 8) {
                                    Button(action: writeToCurrentApp) {
                                        HStack {
                                            if automationManager.isAutomating {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .foregroundColor(.white)
                                            } else {
                                                Image(systemName: getAutomationIcon(for: context.appName))
                                                    .font(.system(size: 14))
                                            }
                                            
                                            Text(automationManager.isAutomating ? "Writing..." : "Write to \(context.appName)")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: getAutomationColors(for: context.appName)),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(20)
                                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(automationManager.isAutomating)
                                    
                                    // Show automation strategy
                                    if let capabilities = automationManager.getAutomationCapabilities(for: context.appName) {
                                        Text("Strategy: \(getStrategyDescription(capabilities.automationStrategy))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Show last automation result if available
                                    if !automationManager.lastAutomationResult.isEmpty {
                                        Text(automationManager.lastAutomationResult)
                                            .font(.caption2)
                                            .foregroundColor(automationManager.lastAutomationResult.contains("Success") ? .green : .orange)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: shouldWriteToApp)
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .clipped()
                
                if isLoading {
                    LoadingIndicator(animation: .threeBallsTriangle, color: .white, size: .medium, speed: .normal)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func captureScreenshot() {
        print("📸 CAPTURING SCREENSHOT - SAVING DOGS & CATS!")
        
        isCapturingScreenshot = true
        
        // Hide the current window temporarily for clean screenshot
        if let windowManager = NSApp.delegate as? WindowManager {
            windowManager.hideWindow()
        }
        
        // Wait a moment for window to hide, then capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performScreenCapture()
        }
    }
    
    private func performScreenCapture() {
        Task {
            do {
                print("📸 Starting ScreenCaptureKit capture...")
                
                // Check if ScreenCaptureKit is available (macOS 12.3+)
                guard #available(macOS 12.3, *) else {
                    print("❌ ScreenCaptureKit requires macOS 12.3 or later")
                    await MainActor.run {
                        isCapturingScreenshot = false
                        showWindow()
                    }
                    return
                }
                
                // Get all displays and windows
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let display = content.displays.first else {
                    print("❌ No displays found")
                    await MainActor.run {
                        isCapturingScreenshot = false
                        showWindow()
                    }
                    return
                }
                
                // Create configuration for screenshot
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = true
                
                // Create filter with the display (exclude our own window)
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Take screenshot using the correct API
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                
                // Convert to NSImage
                let screenshot = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                
                await MainActor.run {
                    // Set the captured image
                    withAnimation {
                        self.selectedImage = screenshot
                    }
                    
                    isCapturingScreenshot = false
                    
                    // Show the window again
                    showWindow()
                    
                    // Auto-focus search field for immediate interaction
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                    }
                    
                    print("✅ SCREENSHOT CAPTURED & ATTACHED! Dogs & Cats SAVED!")
                }
                
            } catch {
                print("❌ Screenshot failed: \(error)")
                await MainActor.run {
                    isCapturingScreenshot = false
                    showWindow()
                    
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
    
    private func showWindow() {
        if let windowManager = NSApp.delegate as? WindowManager {
            windowManager.forceShowWindow()
        }
    }

    private func generateResponse() {
        guard !searchText.isEmpty || selectedImage != nil else { return }
        
        // Check if we need to ask for permission first (only once)
        if memoryManager.shouldAskPermission() {
            memoryManager.requestPermission()
            return
        }
        
        let userInput = searchText
        
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
                
                // Get contextual prompt that includes what user is currently doing
                let contextualPrompt = contextManager.getContextualPrompt(for: userInput)
                let fullPrompt = memoryContext.isEmpty ? contextualPrompt : "\(memoryContext)\n\n\(contextualPrompt)"
                
                if let image = selectedImage {
                    // Convert NSImage to Data
                    guard let tiffData = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiffData),
                          let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
                        throw NSError(domain: "ImageConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
                    }
                    
                    let prompt = userInput.isEmpty ? "What do you see in this image?" : fullPrompt
                    let imagePart = ModelContent.Part.data(mimetype: "image/jpeg", jpegData)
                    result = try await model.generateContent(prompt, imagePart)
                    withAnimation {
                        self.selectedImage = nil // Clear image after sending
                    }
                } else {
                    result = try await model.generateContent(fullPrompt)
                }
                
                let resultText = result.text ?? "No response found"
                response = LocalizedStringKey(resultText)
                responseText = resultText
                
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
    
    // MARK: - Universal Search Methods
    
    private func handleSearch() {
        print("🚀 ENTER PRESSED - SMART APP DETECTION! Saving cats & dogs!")
        
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
        
        // 🎯 SMART APP DETECTION - Check if current context is any supported app
        if let context = contextManager.currentContext, context.canWriteIntoApp {
            let appName = context.appName.lowercased()
            print("✅ CONTEXT FOUND - PROCEEDING WITH APP-SPECIFIC AUTOMATION for: '\(appName)'")
            
            // 📱 MINIMIZE SEARCHFAST IMMEDIATELY for ALL supported apps!
            print("📱 MINIMIZING SearchFast immediately for \(context.appName)!")
            if let windowManager = NSApp.delegate as? WindowManager {
                windowManager.hideWindow()
            }
            
            // Detect supported apps automatically - NO KEYWORDS REQUIRED!
            if appName.contains("cursor") {
                print("🎯 CURSOR DETECTED - Auto-code writing mode!")
                handleCursorAutoWriteMinimized()
                return
            } else if appName.contains("microsoft word") || appName.contains("word") {
                print("📝 MICROSOFT WORD DETECTED - Auto-document writing mode!")
                handleWordAutoWriteMinimized()
                return
            } else if appName.contains("microsoft excel") || appName.contains("excel") {
                print("📊 EXCEL DETECTED - Auto-spreadsheet writing mode!")
                handleExcelAutoWriteMinimized()
                return
            } else if appName.contains("visual studio code") || appName.contains("vs code") {
                print("💻 VS CODE DETECTED - Auto-code writing mode!")
                handleVSCodeAutoWriteMinimized()
                return
            } else if appName.contains("xcode") {
                print("🔨 XCODE DETECTED - Auto-code writing mode!")
                handleXcodeAutoWriteMinimized()
                return
            } else if appName.contains("pages") {
                print("📄 PAGES DETECTED - Auto-document writing mode!")
                handlePagesAutoWriteMinimized()
                return
            } else if appName.contains("keynote") {
                print("🎬 KEYNOTE DETECTED - Auto-presentation writing mode!")
                handleKeynoteAutoWriteMinimized()
                return
            } else {
                print("📝 SUPPORTED APP DETECTED: \(context.appName) - Auto-writing mode!")
                handleGenericAppAutoWriteMinimized(appName: context.appName)
                return
            }
        } else {
            print("❌ NO VALID CONTEXT OR APP DOESN'T SUPPORT WRITING")
            if let context = contextManager.currentContext {
                print("   - Current app: '\(context.appName)'")
                print("   - Can write: \(context.canWriteIntoApp)")
            }
        }
        
        print("🤖 FALLING BACK TO GENERAL AI RESPONSE")
        // DIRECTLY go to AI chat when Enter is pressed - this is what users expect!
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
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
