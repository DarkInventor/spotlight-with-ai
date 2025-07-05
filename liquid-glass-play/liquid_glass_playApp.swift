//
//  liquid_glass_playApp.swift
//  liquid-glass-play
//
//  Created by Kathan Mehta on 2025-06-27.
//

import SwiftUI
import FirebaseCore
#if canImport(AppKit)
import AppKit
import ApplicationServices
import ServiceManagement

// App delegate to handle background operations
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes - stay in background
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App finished launching - ready for background operation")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 App terminating")
    }
}

// Custom borderless window class that ALWAYS can become key window (like Spotlight)
class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.isMovable = false
    }
    
    // Accept first responder to allow typing
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // Prevent window from being moved
    override var isMovable: Bool {
        get { return false }
        set { /* ignore */ }
    }
}
#endif

@main
struct liquid_glass_playApp: App {
    @StateObject private var windowManager = WindowManager()
    
    init() {
        // Configure Firebase with error handling
        do {
        FirebaseApp.configure()
            print("✅ Firebase configured successfully")
        } catch {
            print("⚠️ Firebase configuration failed: \(error.localizedDescription)")
            // Continue without Firebase rather than crash
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(windowManager)
                .background(Color.clear)
                .focusedSceneValue(\.windowManager, windowManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .defaultSize(width: 640, height: 72)
        .commands {
            CommandGroup(after: .windowArrangement) {
                // Window menu commands
                WindowCommands(windowManager: windowManager)
                
                Divider()
                
                Button("Setup Global Hotkey...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowHotkeyInstructions"), object: nil)
                }
            }
        }
    }
}

#if canImport(AppKit)
class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    @Published var isVisible: Bool = false
    @Published var isConfigured: Bool = false
    @Published var isFirstLaunch: Bool = false
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var justOpened: Bool = false
    
    // CRITICAL: Track event monitors to prevent keyboard blocking
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var escapeKeyMonitor: Any?
    private var isInitialized: Bool = false

    
    override init() {
        super.init()
        isInitialized = false
        
        print("⏳ WindowManager created. Waiting for app to finish launching before setup...")
        // Defer the main setup until after the app launch cycle completes.
        // This prevents race conditions and ensures system services are ready,
        // which is critical for launch-at-login reliability.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc private func handleAppDidFinishLaunching() {
        // This setup should only ever run once.
        guard !isInitialized else { return }
        
        // Ask to move to /Applications folder on first launch from a different location
        promptToMoveToApplicationsFolderIfNeeded()
        
        print("🚀 App did finish launching. Starting WindowManager setup...")
        
        do {
            // Clean up any existing monitors first in case of a strange state
            cleanup()
            
            // The original setup logic from init()
            setupMenuBarIcon()
            setupGlobalHotkey()
            setupBackgroundOperation()
            
            // Explicitly set up the window here to ensure it's ready on background launch.
            // This is crucial for the hotkey to work after a restart.
            setupWindow()
            
            checkFirstTimeLaunch()
            registerForLoginIfNeeded()
            // The monitoring timer is no longer needed.
            // setupLaunchAtLoginMonitoring()
            setupCrashRecovery()
            setupHealthCheck()
            
            print("✅ WindowManager initialized successfully.")
            
            isInitialized = true
        } catch {
            print("❌ CRITICAL: WindowManager initialization failed during post-launch setup: \(error)")
            cleanup()
            // isInitialized remains false
        }
        
        // We are done with this notification.
        NotificationCenter.default.removeObserver(self, name: NSApplication.didFinishLaunchingNotification, object: nil)
    }
    
    private func setupHealthCheck() {
        // Check app health every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Check for broken states
            let hasWindow = self.window != nil
            let hasKeyMonitors = self.globalKeyMonitor != nil || self.localKeyMonitor != nil
            let isInitializedProperly = self.isInitialized
            
            print("🏥 Health Check - Window: \(hasWindow), Monitors: \(hasKeyMonitors), Initialized: \(isInitializedProperly)")
            
            // Detect and fix broken states
            if hasKeyMonitors && !hasWindow {
                print("🚨 HEALTH CHECK: Detected keyboard monitors without window - cleaning up")
                self.cleanup()
            }
            
            if !isInitializedProperly && hasKeyMonitors {
                print("🚨 HEALTH CHECK: Detected monitors while not initialized - cleaning up")
                self.cleanup()
            }
            
            // If window exists but app isn't properly initialized, reinitialize
            if hasWindow && !isInitializedProperly {
                print("🚨 HEALTH CHECK: Window exists but not initialized - attempting recovery")
                self.cleanup()
                self.setupWindow()
                self.isInitialized = true
            }
        }
    }
    
    private func registerForLoginIfNeeded() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else { return }

        // This is the correct, modern way to manage a helper-based Login Item.
        // This MUST EXACTLY match the CFBundleIdentifier in the launcher's Info.plist.
        let launcherBundleId = "com.kathan.liquid-glass-play.Launcher"
        let service = SMAppService.loginItem(identifier: launcherBundleId)

        Task {
            do {
                try await service.register()
                print("🚀 Successfully registered launcher for login.")
            } catch {
                print("❌ CRITICAL: Failed to register launcher for launch at login: \(error.localizedDescription)")
            }
        }
    }
     
     private func setupLaunchAtLoginMonitoring() {
        // This check is no longer needed with the modern API, as the system handles it.
        // We can remove the timer to simplify the code.
    }
    

    
    deinit {
        print("🧹 WindowManager deinitializing - cleaning up event monitors")
        cleanup()
    }
    
    private func checkFirstTimeLaunch() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        isFirstLaunch = !hasCompletedOnboarding
        
        if !hasCompletedOnboarding {
            print("🎉 FIRST LAUNCH DETECTED! Setting up onboarding flow...")
            
            // First time launch - trigger onboarding after ContentView is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🎉 First time launch - triggering onboarding automatically")
                
                // Ensure window is set up first
                if self.window == nil {
                    self.setupWindow()
                }
                
                // Post notification to ContentView to show onboarding
                NotificationCenter.default.post(name: NSNotification.Name("ShowOnboardingOnFirstLaunch"), object: nil)
                
                // Show the window with onboarding size
                self.showOnboardingWindow()
            }
        }
        // If onboarding is completed, start hidden as usual
    }
    

    
    private func setupMenuBarIcon() {
        // Remove any existing status item first
        if let currentStatusItem = statusItem {
            NSStatusBar.system.removeStatusItem(currentStatusItem)
        }
        
        // Create new status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "SearchFast")
        }
        
        // Create menu
        let menu = NSMenu()
        
        // Add emergency quit option at the top
        let emergencyQuitItem = NSMenuItem(title: "Force Quit (Emergency)", action: #selector(emergencyQuit), keyEquivalent: "q")
        emergencyQuitItem.keyEquivalentModifierMask = [.command, .option, .shift]
        emergencyQuitItem.target = self
        menu.addItem(emergencyQuitItem)
        
        menu.addItem(NSMenuItem.separator())

        // Add regular menu items
        let showItem = NSMenuItem(title: "Show SearchFast", action: #selector(toggleWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        let checkStatusItem = NSMenuItem(title: "Check Launch at Login Status", action: #selector(checkLaunchAtLoginStatus), keyEquivalent: "")
        checkStatusItem.target = self
        menu.addItem(checkStatusItem)
        
        let resetItem = NSMenuItem(title: "Reset Onboarding...", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        let permissionsItem = NSMenuItem(title: "Request Permissions Manually", action: #selector(requestPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    

    
    @objc func showHotkeyInstructions() {
        // Post notification to show instructions
        NotificationCenter.default.post(name: NSNotification.Name("ShowHotkeyInstructions"), object: nil)
    }
    
    @objc func requestPermissions() {
        Task { @MainActor in
            print("🔐 Manually requesting permissions...")
            let permissionManager = PermissionManager()
            await permissionManager.requestAllPermissions()
            
            // Show updated permission status
            let summary = permissionManager.getPermissionStatusSummary()
            let message = """
            Permission Status:
            
            \(summary)
            
            \(permissionManager.allPermissionsGranted ? "All required permissions granted! The app should work properly now." : "Some permissions are missing. Please grant them for full functionality.")
            """
            
            let alert = NSAlert()
            alert.messageText = "Permission Status"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hotkeyInstructionsShown")
        
        // Switch to regular mode to show onboarding
        NSApp.setActivationPolicy(.regular)
        
        // Simulate first launch
        isFirstLaunch = true
        
        // Show the onboarding again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("ShowOnboarding"), object: nil)
            self.showOnboardingWindow()
        }
    }
    
    @objc func checkLaunchAtLoginStatus() {
        // This is the correct, modern way to manage a helper-based Login Item.
        // This MUST EXACTLY match the CFBundleIdentifier in the launcher's Info.plist.
        let launcherBundleId = "com.kathan.liquid-glass-play.Launcher"
        let service = SMAppService.loginItem(identifier: launcherBundleId)
        
        let status = service.status
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        var message = "Launch at Login Status: "
        
        switch status {
        case .enabled:
            message += "✅ Enabled\n\nSearchFast will start automatically when you restart your Mac."
        case .notRegistered:
            message += "❌ Disabled\n\nSearchFast will not start automatically. You can enable it in System Settings > General > Login Items."
        case .requiresApproval:
            message += "⚠️ Requires Approval\n\nTo enable SearchFast at login, please go to System Settings > General > Login Items and approve it."
        case .notFound:
             message += "⚠️ Not Found\n\nThe helper application might be missing or corrupted. Please try reinstalling the app."
        @unknown default:
            message += "❓ Unknown Status: \(status)\n\nThis is an unexpected status."
        }
        
        let alert = NSAlert()
        alert.messageText = "Launch at Login Status"
        alert.informativeText = message
        alert.alertStyle = .informational
        
        if status == .requiresApproval || status == .notRegistered {
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Login Items
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupBackgroundOperation() {
        // Only set accessory mode if onboarding is completed
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompletedOnboarding {
            // Configure app to run in background only after onboarding
        NSApp.setActivationPolicy(.accessory) // This makes the app not appear in the dock
        } else {
            // Keep regular mode for first launch to show onboarding
            print("🎉 First launch - keeping regular activation policy for onboarding")
            NSApp.setActivationPolicy(.regular)
        }
        
        // Handle app becoming active/inactive
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 App became active")
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 App resigned active - continuing in background")
        }
        
        // Prevent app from terminating when window closes
        NSApp.delegate = AppDelegate.shared
    }
    
    @objc func toggleWindow() {
        guard isInitialized else {
            print("⚠️ SAFETY: Cannot toggle window - WindowManager not initialized")
            return
        }
        
        if isVisible {
            hideWindow()
        } else {
            forceShowWindow()
        }
    }
    
    func forceShowWindow() {
        guard isInitialized else {
            print("⚠️ SAFETY: Cannot show window - WindowManager not initialized")
            return
        }
        
        guard let window = window else {
            print("❌ No window available - setting up window first")
            setupWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.forceShowWindow()
            }
            return
        }
        
        // If already visible, just bring to front and focus
        if isVisible {
            print("🔄 Window already visible - bringing to front")
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            window.makeKeyAndOrderFront(nil)
            
            // Focus the search field
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                self.findAndFocusTextFieldDirectly()
            }
            return
        }
        
        // CAPTURE CONTEXT BEFORE ANYTHING ELSE!
        // Get the currently frontmost app BEFORE we steal focus
        let currentApp = NSWorkspace.shared.frontmostApplication
        print("🎯 CAPTURING CONTEXT FOR: \(currentApp?.localizedName ?? "Unknown")")
        
        // Post notification with the current app info IMMEDIATELY
        NotificationCenter.default.post(
            name: NSNotification.Name("CaptureContextBeforeShow"), 
            object: currentApp
        )
        
        isVisible = true
        justOpened = true
        
        // Force the app to become active and bring window to front
        // Temporarily switch to regular mode to show window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set window to high level but not so high that it blocks drag operations
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        // Center and show window
        centerWindow()
        window.makeKeyAndOrderFront(nil)
        
        // NUCLEAR FOCUS STRATEGY - SAVE THE CATS!
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            self.findAndFocusTextFieldDirectly()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            self.findAndFocusTextFieldDirectly()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            self.findAndFocusTextFieldDirectly()
            // Return to accessory mode after ensuring focus
            NSApp.setActivationPolicy(.accessory)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            self.findAndFocusTextFieldDirectly()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            self.findAndFocusTextFieldDirectly()
        }
        
        // Reset the justOpened flag after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.justOpened = false
        }
    }
    
    @objc func showWindowFromMenu() {
        if !isVisible {
            showWindow()
        }
    }
    
    func setupWindow() {
        guard !isConfigured else {
            print("🔄 Window already configured")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var windowToConfigure: NSWindow?

            // First, check if we already have a reference to our window
            if let existingWindow = self.window {
                print("✅ Found existing window reference.")
                windowToConfigure = existingWindow
            } else {
                // If not, try to find a suitable window created by SwiftUI
                print("🧐 No existing reference, searching for a SwiftUI-managed window...")
                windowToConfigure = NSApplication.shared.windows.first {
                    !$0.className.contains("StatusBar") && $0.contentView != nil
                }
            }

            // If we STILL don't have a window, it means we launched in the background
            // and must create it programmatically. This is the KEY to fixing boot launch.
            if windowToConfigure == nil {
                print("🚀 No window found. Creating one programmatically for background launch.")
                
                // Create the content view
                let contentView = ContentView()
                    .environmentObject(self)
                    .background(Color.clear)
                    .focusedSceneValue(\.windowManager, self)
                
                let hostingView = NSHostingView(rootView: contentView)
                
                // Create our custom Spotlight-style window
                let newWindow = SpotlightWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 640, height: 72),
                    styleMask: [.borderless, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                newWindow.contentView = hostingView
                windowToConfigure = newWindow
            }

            guard let window = windowToConfigure else {
                print("❌ CRITICAL FAILURE: Could not find or create a window. Aborting setup.")
                // We shouldn't retry here, as it indicates a fundamental problem.
                return
            }
            
            // If the window we found isn't our custom class, replace it.
            if !(window is SpotlightWindow) {
                 print("🔄 Window is not a SpotlightWindow, replacing it.")
                 let spotlightWindow = SpotlightWindow(contentRect: window.frame,
                                                     styleMask: [.borderless, .fullSizeContentView],
                                                     backing: .buffered,
                                                     defer: false)
                 spotlightWindow.contentView = window.contentView
                 
                 // Configure the new spotlight window
                 spotlightWindow.backgroundColor = NSColor.clear
                 spotlightWindow.isOpaque = false
                 spotlightWindow.hasShadow = false
                 spotlightWindow.level = .floating
                 spotlightWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                 spotlightWindow.isMovable = false
                 
                 // Replace the window
                 window.orderOut(nil) // Hide the old window
                 self.window = spotlightWindow
            } else {
                // It's already the correct type, just assign it.
                self.window = window
            }
            
            // Now, self.window is guaranteed to be a valid SpotlightWindow.
            guard let finalWindow = self.window else {
                 print("❌ CRITICAL FAILURE: Window reference lost after configuration.")
                 return
            }

            // Configure window to be COMPLETELY TRANSPARENT
            finalWindow.backgroundColor = NSColor.clear
            finalWindow.isOpaque = false
            finalWindow.hasShadow = false
            finalWindow.level = .floating

            // CRITICAL: Borderless with no visual artifacts
            finalWindow.styleMask = [.borderless, .fullSizeContentView]
            finalWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            finalWindow.isMovable = false

            // Set up delegate for window events (like losing focus)
            finalWindow.delegate = self
            
            finalWindow.alphaValue = 1.0
            finalWindow.ignoresMouseEvents = false
            finalWindow.tabbingMode = .disallowed
            finalWindow.isRestorable = false
            
            // Allow keyboard input
            finalWindow.canHide = false
            finalWindow.hidesOnDeactivate = false
            
            // Set initial size
            let windowSize = NSSize(width: 640, height: 72)
            finalWindow.setContentSize(windowSize)
            
            self.centerWindow()
            
            // Hide window initially
            finalWindow.orderOut(nil)
            self.isVisible = false
            self.isConfigured = true
            
            print("✅ Window setup complete. Ready for action.")
            
            // Setup escape key monitoring once window is ready
            self.setupEscapeKeyMonitor()
        }
    }
    
    func showWindow() {
        forceShowWindow()
    }
    
    func hideWindow() {
        guard let window = window else { return }
        
        isVisible = false
        
        // Reset window level to normal floating
        window.level = .floating
        window.orderOut(nil)
        
        // Switch back to accessory mode if onboarding is completed
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompletedOnboarding {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Clear search when hiding
        NotificationCenter.default.post(name: NSNotification.Name("ClearSearch"), object: nil)
        
        // Clear the locked context when hiding
        NotificationCenter.default.post(name: NSNotification.Name("ClearLockedContext"), object: nil)
    }
    
    func updateWindowHeight(_ height: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            let newSize = NSSize(width: 640, height: max(72, height))
            window.setContentSize(newSize)
            self.centerWindow()
        }
    }
    
    // 🎉 NEW: Handle onboarding window sizing
    func showOnboardingWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // Resize window for onboarding
            let onboardingSize = NSSize(width: 800, height: 650)
            window.setContentSize(onboardingSize)
            self.centerWindow()
            
            // Show the window
            self.forceShowWindow()
        }
    }
    
    func hideOnboardingWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // Reset to normal size
            let normalSize = NSSize(width: 640, height: 72)
            window.setContentSize(normalSize)
            self.centerWindow()
            
            // Hide the window
            self.hideWindow()
        }
    }
    
    private func centerWindow() {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let centerX = screenFrame.midX - windowFrame.width / 2
        let centerY = screenFrame.midY - windowFrame.height / 2 + 100 // Slightly above center like Spotlight
        
        window.setFrameOrigin(NSPoint(x: centerX, y: centerY))
    }
    
    private func setupGlobalHotkey() {
        setupCarbonHotkey()
        setupClickOutsideMonitoring()
    }
    
    private func setupClickOutsideMonitoring() {
        // Clean up existing monitor first
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        
        // Monitor global mouse clicks to hide window when clicking outside
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isInitialized else { 
                print("⚠️ Ignoring mouse event - WindowManager not fully initialized")
                return 
            }
            
            if let window = self.window, self.isVisible == true {
                let clickLocation = event.locationInWindow
                let windowFrame = window.frame
                
                // Convert click location to screen coordinates
                if let screen = window.screen {
                    let screenClickLocation = NSPoint(
                        x: clickLocation.x + windowFrame.origin.x,
                        y: clickLocation.y + windowFrame.origin.y
                    )
                    
                    // Check if click is outside our window
                    if !windowFrame.contains(screenClickLocation) {
                        DispatchQueue.main.async {
                            self.hideWindow()
                        }
                    }
                }
            }
        }
        
        if globalMouseMonitor != nil {
            print("✅ Global mouse monitor set up successfully")
        } else {
            print("❌ Failed to set up global mouse monitor")
        }
    }
    
    private func setupCarbonHotkey() {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            setupLocalHotkey()
            
            // Set up a timer to check permissions periodically
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.setupGlobalMonitoring()
                    timer.invalidate()
                }
            }
            return
        }
        
        setupGlobalMonitoring()
        setupLocalHotkey()
    }
    
    private func setupGlobalMonitoring() {
        // Clean up existing monitor first - CRITICAL to prevent keyboard blocking
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
            print("🧹 Cleaned up existing global key monitor")
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isInitialized else { 
                print("⚠️ CRITICAL: Ignoring global key event - WindowManager not initialized. This prevents keyboard blocking!")
                return 
            }
            
            // Add safety check to ensure we don't block if window is nil
            guard self.window != nil else {
                print("⚠️ SAFETY: No window available - ignoring global hotkey to prevent system freeze")
                return
            }
            
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // Cmd+Shift+Space
                print("🔥 GLOBAL HOTKEY PRESSED! Checking system health...")
                
                // Safety check before processing
                guard self.isInitialized && self.window != nil else {
                    print("❌ SAFETY ABORT: App not ready for hotkey processing")
                    return
                }
                
                // CAPTURE CONTEXT IMMEDIATELY when hotkey is pressed, before window shows
                let currentApp = NSWorkspace.shared.frontmostApplication
                print("🎯 Current frontmost app: \(currentApp?.localizedName ?? "Unknown")")
                
                // Store the context immediately
                NotificationCenter.default.post(
                    name: NSNotification.Name("CaptureContextBeforeShow"), 
                    object: currentApp
                )
                
                DispatchQueue.main.async {
                    self.toggleWindow()
                }
            } else if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                if self.isVisible == true {
                    DispatchQueue.main.async {
                        self.hideWindow()
                    }
                }
            }
        }
        
        if globalKeyMonitor != nil {
            print("✅ Global key monitor set up successfully with safety checks")
        } else {
            print("❌ CRITICAL: Failed to set up global key monitor")
        }
    }
    
    private func setupLocalHotkey() {
        // Clean up existing local monitor
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
            print("🧹 Cleaned up existing local key monitor")
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isInitialized else { 
                print("⚠️ Ignoring local key event - WindowManager not initialized")
                return event // Don't consume event if not ready
            }
            
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // Cmd+Shift+Space
                // Safety check before processing
                guard self.window != nil else {
                    print("⚠️ SAFETY: Local hotkey ignored - no window available")
                    return event
                }
                
                // CAPTURE CONTEXT IMMEDIATELY when hotkey is pressed, before window shows
                let currentApp = NSWorkspace.shared.frontmostApplication
                print("🔥 LOCAL HOTKEY PRESSED! Current frontmost app: \(currentApp?.localizedName ?? "Unknown")")
                
                // Store the context immediately
                NotificationCenter.default.post(
                    name: NSNotification.Name("CaptureContextBeforeShow"), 
                    object: currentApp
                )
                
                DispatchQueue.main.async {
                    self.toggleWindow()
                }
                return nil // Consume the event
            } else if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                if self.isVisible == true {
                    DispatchQueue.main.async {
                        self.hideWindow()
                    }
                    return nil // Consume the event
                }
            }
            return event
        }
        
        if localKeyMonitor != nil {
            print("✅ Local key monitor set up successfully")
        } else {
            print("❌ Failed to set up local key monitor")
        }
    }
    

    
    private func setupEscapeKeyMonitor() {
        // Clean up existing escape monitor
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
            print("🧹 Cleaned up existing escape key monitor")
        }
        
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isInitialized else { 
                return event // Don't consume if not ready
            }
            
            if event.keyCode == 53 && self.isVisible == true { // Escape key
                self.hideWindow()
                return nil // Consume the event
            }
            return event
        }
        
        if escapeKeyMonitor != nil {
            print("✅ Escape key monitor set up successfully")
        } else {
            print("❌ Failed to set up escape key monitor")
        }
    }
    

    // MARK: - Direct Focus Methods
    
    private func findAndFocusTextFieldDirectly() {
        guard let window = window, let contentView = window.contentView else { return }
        findTextFieldInView(contentView)
    }
    
    private func findTextFieldInView(_ view: NSView) {
        // Look for NSTextField in the view hierarchy
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                DispatchQueue.main.async {
                    self.window?.makeFirstResponder(textField)
                    textField.becomeFirstResponder()
                    textField.selectText(nil)
                }
                return
            }
            // Recursively search subviews
            findTextFieldInView(subview)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        // Hide window when it loses key status (user clicked elsewhere)
        // But only if it wasn't just opened
        if isVisible && !justOpened {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                // Only hide if we're still not the key window after the delay
                if let window = self?.window, !window.isKeyWindow && self?.isVisible == true && self?.justOpened == false {
                    // Check if any of our app's windows are key (to avoid hiding during internal focus changes)
                    let hasKeyWindow = NSApp.windows.contains { $0.isKeyWindow && $0.contentView != nil }
                    if !hasKeyWindow {
                        self?.hideWindow()
                    }
                }
            }
        }
    }
    
    func windowDidResignMain(_ notification: Notification) {
        // Don't hide on resignMain as it can interfere with focus
        // Let windowDidResignKey handle the hiding
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // When window becomes key, ensure search field gets focus
        if isVisible {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                self.findAndFocusTextFieldDirectly()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                self.findAndFocusTextFieldDirectly()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                self.findAndFocusTextFieldDirectly()
            }
        }
    }
    
    private func cleanup() {
        print("🧹 CRITICAL CLEANUP: Removing all event monitors to prevent keyboard blocking")
        
        // Remove all event monitors - CRITICAL to prevent keyboard blocking
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
            print("✅ Removed global key monitor")
        }
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
            print("✅ Removed local key monitor")
        }
        
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
            print("✅ Removed global mouse monitor")
        }
        
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
            print("✅ Removed escape key monitor")
        }
        
        // Remove status bar item
        if let currentStatusItem = statusItem {
            NSStatusBar.system.removeStatusItem(currentStatusItem)
            statusItem = nil
            print("✅ Removed status bar item")
        }
        
        // Mark as not initialized
        isInitialized = false
        
        print("✅ CLEANUP COMPLETE: All event monitors removed, keyboard unblocked")
    }
    
    private func setupCrashRecovery() {
        // Set up emergency quit mechanism using a different hotkey
        // This runs independently and can clean up even if main app crashes
        let emergencyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Emergency quit: Cmd+Option+Shift+Q+Q (press Q twice)
            if event.modifierFlags.contains([.command, .option, .shift]) && event.keyCode == 12 { // Q key
                print("🚨 EMERGENCY QUIT TRIGGERED - Force cleanup and quit")
                self?.emergencyQuit()
            }
        }
        
        // Store emergency monitor separately (not cleaned up in normal cleanup)
        if emergencyMonitor != nil {
            print("🆘 Emergency quit mechanism active: Cmd+Option+Shift+Q")
        }
        
        // Set up periodic health check
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Check if we're in a broken state (no window but monitors active)
            if self.globalKeyMonitor != nil && self.window == nil && self.isInitialized {
                print("🚨 DETECTED BROKEN STATE: Event monitors active but no window - cleaning up")
                self.cleanup()
                timer.invalidate()
            }
        }
    }
    
    @objc private func emergencyQuit() {
        print("🚨 EMERGENCY QUIT: Forcing immediate cleanup and termination")
        
        // Force cleanup of ALL event monitors immediately
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
        
        // Remove status bar item to prevent ghost menu
        if let currentStatusItem = statusItem {
            NSStatusBar.system.removeStatusItem(currentStatusItem)
            statusItem = nil
        }
        
        // Force quit the application immediately
        exit(0) // Use exit(0) instead of NSApplication.shared.terminate for guaranteed quit
    }
    
    private func promptToMoveToApplicationsFolderIfNeeded() {
        #if !DEBUG
        // Don't ask in debug builds
        let hasBeenAsked = UserDefaults.standard.bool(forKey: "hasBeenAskedToMoveToApplications")
        if hasBeenAsked { return }

        let bundleURL = Bundle.main.bundleURL

        guard let applicationsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first else { return }

        // If we're already in any subfolder of /Applications, we're good.
        if bundleURL.path.hasPrefix(applicationsURL.path) {
            return
        }

        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "the app"
        
        let alert = NSAlert()
        alert.messageText = "Move “\(appName)” to Applications folder?"
        alert.informativeText = "To ensure the app works correctly and can be easily found, it's best to keep it in your Applications folder."
        alert.addButton(withTitle: "Move to Applications Folder")
        alert.addButton(withTitle: "Don't Move")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            moveToApplications()
        } else {
            // User chose not to move, so don't ask again.
            UserDefaults.standard.set(true, forKey: "hasBeenAskedToMoveToApplications")
        }
        #endif
    }

    private func moveToApplications() {
        let bundleURL = Bundle.main.bundleURL
        guard let applicationsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first else {
            showMoveErrorAlert(message: "Could not find the Applications folder.")
            return
        }

        let destinationURL = applicationsURL.appendingPathComponent(bundleURL.lastPathComponent)

        // Using AppleScript with `ditto` is the most reliable way to move an application
        // bundle and request administrator privileges.
        let scriptString = """
        do shell script "ditto \\"\(bundleURL.path)\\" \\"\(destinationURL.path)\\"" with administrator privileges
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptString) {
            DispatchQueue.global(qos: .userInitiated).async {
                if script.executeAndReturnError(&error) != nil {
                    // Success! Relaunch from the new location and quit the old one.
                    NSWorkspace.shared.open(destinationURL)
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                } else {
                    // Failure
                    let errorMessage = error?["NSAppleScriptErrorMessage"] as? String ?? "An unknown error occurred."
                    DispatchQueue.main.async {
                        // Check if the user cancelled the password prompt.
                        if (error?["NSAppleScriptErrorNumber"] as? Int) == -128 {
                            // Don't show an error if the user just clicked "Cancel".
                            // They might want to move it manually later.
                            print("User cancelled moving the application.")
                        } else {
                            self.showMoveErrorAlert(message: "Failed to move the app automatically. Please drag it to your Applications folder manually. Error: \(errorMessage)")
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.showMoveErrorAlert(message: "Could not prepare the script to move the application. Please drag it to your Applications folder manually.")
            }
        }
    }

    private func showMoveErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error Moving Application"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// Virtual key code constants
private let kVK_ANSI_J: Int32 = 0x26

// FocusedValues extension for better SwiftUI integration
struct WindowManagerKey: FocusedValueKey {
    typealias Value = WindowManager
}

extension FocusedValues {
    var windowManager: WindowManagerKey.Value? {
        get { self[WindowManagerKey.self] }
        set { self[WindowManagerKey.self] = newValue }
    }
}

// Window Commands for better menu integration
struct WindowCommands: View {
    let windowManager: WindowManager
    
    var body: some View {
        Group {
            Button(windowManager.isVisible ? "Hide AI Spotlight" : "Show AI Spotlight") {
                windowManager.toggleWindow()
            }
            
            Divider()
            
            if windowManager.isVisible {
                Button("Hide Window") {
                    windowManager.hideWindow()
                }
                .keyboardShortcut(.escape)
            }
            
            Button("Focus Search") {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(!windowManager.isVisible)
        }
    }
}
#endif

