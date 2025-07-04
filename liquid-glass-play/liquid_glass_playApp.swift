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
                .onAppear {
                    windowManager.setupWindow()
                }
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
        
        // Mark as NOT initialized until everything is ready
        isInitialized = false
        
        do {
            // Clean up any existing monitors first
            cleanup()
            
            // Robust initialization with error handling
        setupMenuBarIcon()
        setupGlobalHotkey()
        setupBackgroundOperation()
        
        // Permissions are now handled in onboarding flow
        
        // Check if this is first time launch - if so, show window automatically
        checkFirstTimeLaunch()
        registerForLoginIfNeeded()
            
            // Set up periodic check for launch at login status
            setupLaunchAtLoginMonitoring()
            
            // Add crash detection and recovery
            setupCrashRecovery()
            
            // Set up periodic health check
            setupHealthCheck()
            
            print("✅ WindowManager initialized successfully")
            
            // Only mark as initialized if everything succeeded
            isInitialized = true
        } catch {
            print("❌ CRITICAL: WindowManager initialization failed: \(error)")
            cleanup()
            // Keep isInitialized as false
        }
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
        if hasCompletedOnboarding {
            // Check current status first
            let currentStatus = SMAppService.mainApp.status
            print("🔍 Current SMAppService status: \(currentStatus)")
            
            switch currentStatus {
            case .notRegistered:
                 do {
                     try SMAppService.mainApp.register()
                    print("🚀 Successfully registered for launch at login.")
                    
                    // Verify registration with a more comprehensive check
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.verifyLaunchAtLoginStatus()
                    }
                 } catch {
                    print("❌ Failed to register for launch at login: \(error.localizedDescription)")
                    // Store the failure for debugging
                    UserDefaults.standard.set(error.localizedDescription, forKey: "lastRegistrationError")
                    // Try again in a few seconds with exponential backoff
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.retryRegistration()
                    }
                }
                
            case .notFound:
                print("⚠️ App service not found - this may be expected in debug builds")
                // In debug builds, this is normal and we shouldn't retry
                if !isDebugBuild() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                        self.retryRegistration()
                    }
                }
                
            case .enabled:
                print("✅ Launch at login already enabled")
                // Clear any previous error
                UserDefaults.standard.removeObject(forKey: "lastRegistrationError")
                
            case .requiresApproval:
                print("⚠️ Launch at login requires user approval in System Preferences")
                print("💡 User needs to approve in System Preferences > General > Login Items")
                
            @unknown default:
                print("⚠️ Unknown SMAppService status: \(currentStatus)")
            }
        }
    }
    
    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    private func verifyLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        print("🔍 Verified SMAppService status: \(status)")
        
        if status != .enabled {
            print("⚠️ Launch at login not properly enabled. Status: \(status)")
            
            // Store the registration attempt
            UserDefaults.standard.set(Date(), forKey: "lastRegistrationAttempt")
            
            // If it requires approval, log helpful message
            if status == .requiresApproval {
                print("💡 User needs to approve in System Preferences > General > Login Items")
                // Clear retry count since this is a user action requirement, not a technical failure
                UserDefaults.standard.removeObject(forKey: "registrationRetryCount")
            }
        } else {
            print("✅ Launch at login successfully verified")
            // Clear all registration tracking on success
            UserDefaults.standard.removeObject(forKey: "lastRegistrationAttempt")
            UserDefaults.standard.removeObject(forKey: "registrationRetryCount")
            UserDefaults.standard.removeObject(forKey: "lastRegistrationError")
                 }
    }
    
    private func retryRegistration() {
        // Check if we've tried recently to avoid spam
        if let lastAttempt = UserDefaults.standard.object(forKey: "lastRegistrationAttempt") as? Date,
           Date().timeIntervalSince(lastAttempt) < 60 {
            print("⏰ Skipping registration retry - attempted recently")
            return
        }
        
        // Implement exponential backoff to prevent too frequent retries
        let retryCount = UserDefaults.standard.integer(forKey: "registrationRetryCount")
        let maxRetries = 5
        
        if retryCount >= maxRetries {
            print("❌ Max registration retries reached. Manual intervention may be required.")
            UserDefaults.standard.set("Max retries reached", forKey: "lastRegistrationError")
            return
        }
        
        print("🔄 Retrying launch at login registration... (attempt \(retryCount + 1)/\(maxRetries))")
        UserDefaults.standard.set(retryCount + 1, forKey: "registrationRetryCount")
        registerForLoginIfNeeded()
    }
     
     private func setupLaunchAtLoginMonitoring() {
         // Check launch at login status every 10 minutes to ensure it stays enabled
         Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
             guard let self = self else { return }
             
             let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
             guard hasCompletedOnboarding else { return }
             
             let status = SMAppService.mainApp.status
             
             // If the service becomes disabled or unregistered, try to re-register
             if status == .notRegistered {
                 print("🔄 Launch at login became unregistered - attempting to re-register")
                 self.registerForLoginIfNeeded()
             } else if status == .requiresApproval {
                 print("⚠️ Launch at login requires user approval")
            }
        }
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
        let emergencyQuitItem = NSMenuItem(title: "Force Quit (Emergency)", action: #selector(emergencyQuit), keyEquivalent: "")
        emergencyQuitItem.keyEquivalentModifierMask = [.command, .option, .shift]
        emergencyQuitItem.keyEquivalent = "q"
        menu.addItem(emergencyQuitItem)
        
        menu.addItem(NSMenuItem.separator())

        // Add regular menu items
        menu.addItem(NSMenuItem(title: "Show SearchFast", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check Launch at Login Status", action: #selector(checkLaunchAtLoginStatus), keyEquivalent: ""))
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
        }
    }
    
    @objc func checkLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let lastError = UserDefaults.standard.string(forKey: "lastRegistrationError")
        let retryCount = UserDefaults.standard.integer(forKey: "registrationRetryCount")
        
        var message = "Launch at Login Status: "
        var actionable = false
        
        switch status {
        case .enabled:
            message += "✅ Enabled\n\nSearchfast will start automatically when you restart your Mac."
            if retryCount > 0 {
                message += "\n\n✅ Previous registration issues have been resolved."
            }
        case .notRegistered:
            message += "❌ Not Registered\n\nSearchfast will not start automatically after restart."
            if let error = lastError {
                message += "\n\n⚠️ Last error: \(error)"
            }
            if retryCount > 0 {
                message += "\n\nRetry attempts: \(retryCount)/5"
            }
            actionable = hasCompletedOnboarding
        case .requiresApproval:
            message += "⚠️ Requires Approval\n\nSearchfast needs your permission to start automatically."
            message += "\n\nTo approve:"
            message += "\n1. Open System Preferences/Settings"
            message += "\n2. Go to General → Login Items"
            message += "\n3. Find 'Searchfast' and ensure it's enabled"
            message += "\n\nAlternatively, click 'Open System Preferences' below."
        case .notFound:
            if isDebugBuild() {
                message += "⚠️ Service Not Found\n\nThis is expected in debug builds. Launch at login will work in the release version."
            } else {
                message += "❌ Service Not Found\n\nThere may be an issue with the app installation. Try reinstalling the app."
            }
        @unknown default:
            message += "❓ Unknown Status: \(status)\n\nThis is an unexpected status. Please report this issue."
        }
        
        let alert = NSAlert()
        alert.messageText = "Launch at Login Status"
        alert.informativeText = message + "\n\n🆘 Emergency Info:\nIf SearchFast becomes unresponsive and blocks keyboard input, press Cmd+Option+Shift+Q to force quit and restore keyboard control."
        alert.alertStyle = .informational
        
        if actionable {
            alert.addButton(withTitle: "Enable Launch at Login")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Reset retry count when user manually tries
                UserDefaults.standard.removeObject(forKey: "registrationRetryCount")
                registerForLoginIfNeeded()
            }
        } else if status == .requiresApproval {
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Preferences to Login Items
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
        
        guard isInitialized else {
            print("⚠️ Cannot setup window - WindowManager not fully initialized")
            // Retry after initialization completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupWindow()
            }
            return 
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If we already have a window reference, use it
            if let existingWindow = self.window {
                print("🔄 Reusing existing window")
                self.isConfigured = true
                return
            }
            
            // Find the main window - exclude already configured SpotlightWindows
            guard var window = NSApplication.shared.windows.first(where: {
                !$0.className.contains("StatusBar") && 
                $0.contentView != nil && 
                !($0 is SpotlightWindow && $0 == self.window)
            }) else {
                print("❌ No suitable window found for setup - will retry")
                // Retry window setup after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.setupWindow()
                }
                return
            }
            
            // Force borderless window to accept key status (like Spotlight)
            if let spotlightWindow = window as? SpotlightWindow {
                // Already a SpotlightWindow, good!
                self.window = spotlightWindow
            } else {
                // Convert to our custom window class that can become key
                let spotlightWindow = SpotlightWindow(contentRect: window.frame,
                                                    styleMask: [.borderless, .fullSizeContentView],
                                                    backing: .buffered,
                                                    defer: false)
                spotlightWindow.contentView = window.contentView
                
                // Configure the new spotlight window
                spotlightWindow.backgroundColor = NSColor.clear
                spotlightWindow.isOpaque = false
                spotlightWindow.hasShadow = false // No window shadow
                spotlightWindow.level = .floating
                spotlightWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                spotlightWindow.isMovable = false
                spotlightWindow.hasShadow = false // Explicitly disable shadow again
                
                // Replace the window
                window.orderOut(nil) // Hide the old window
                self.window = spotlightWindow
                window = spotlightWindow
            }
            
            // Configure window to be COMPLETELY TRANSPARENT - pure floating content
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false // No window shadow - content provides its own
            window.level = .floating // Float above everything
            
            // CRITICAL: Borderless with no visual artifacts
            window.styleMask = [.borderless, .fullSizeContentView]
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.isMovable = false
            
            // Set up delegate for window events (like losing focus)
            // Temporarily disabled to fix immediate closing issue
            // window.delegate = self
            
            // Ensure completely transparent window frame
            window.alphaValue = 1.0
            window.ignoresMouseEvents = false
            
            // NUCLEAR TAB ELIMINATION - NO TABS EVER! 🚫
            window.tabbingMode = .disallowed
            window.allowsToolTipsWhenApplicationIsInactive = false
            
            // Borderless windows don't have window controls - perfect!
            
            // Extra floating properties for maximum floatiness
            window.isExcludedFromWindowsMenu = true
            window.displaysWhenScreenProfileChanges = true
            window.isRestorable = false
            
            // Allow keyboard input
            window.canHide = false
            window.hidesOnDeactivate = false
            
            // Set initial size - Authentic Spotlight dimensions
            let windowSize = NSSize(width: 640, height: 72)
            window.setContentSize(windowSize)
            
            // Center window
            self.centerWindow()
            
            // Hide window initially
            window.orderOut(nil)
            self.isVisible = false
            
            self.isConfigured = true
            
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

