//
//  liquid_glass_playApp.swift
//  liquid-glass-play
//
//  Created by Kathan Mehta on 2025-06-27.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
import ApplicationServices

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
        .windowResizability(.contentSize)
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
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var justOpened: Bool = false

    
    override init() {
        super.init()
        setupMenuBarIcon()
        setupGlobalHotkey()
        setupBackgroundOperation()
        
        // Start hidden - only show when hotkey is pressed
    }
    
    deinit {
        cleanup()
    }
    

    
    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "AI Spotlight")
            button.action = #selector(toggleWindow)
            button.target = self
            button.toolTip = "Searchfast - Cmd+Shift+Space to toggle, Cmd+J to close"
        }
        
        // Add menu to status item
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show AI Spotlight", action: #selector(showWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Setup Global Hotkey...", action: #selector(showHotkeyInstructions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Searchfast", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Set target for menu items
        for item in menu.items {
            item.target = self
        }
        
        statusItem?.menu = menu
    }
    

    
    @objc func showHotkeyInstructions() {
        // Post notification to show instructions
        NotificationCenter.default.post(name: NSNotification.Name("ShowHotkeyInstructions"), object: nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func setupBackgroundOperation() {
        // Configure app to run in background
        NSApp.setActivationPolicy(.accessory) // This makes the app not appear in the dock
        
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
        if isVisible {
            hideWindow()
        } else {
            forceShowWindow()
        }
    }
    
    func forceShowWindow() {
        guard let window = window else { return }
        
        isVisible = true
        justOpened = true
        
        // Force the app to become active and bring window to front
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
        guard !isConfigured else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the main window
            guard var window = NSApplication.shared.windows.first(where: { 
                !$0.className.contains("StatusBar") && $0.contentView != nil
            }) else {
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
        
        // Clear search when hiding
        NotificationCenter.default.post(name: NSNotification.Name("ClearSearch"), object: nil)
    }
    
    func updateWindowHeight(_ height: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            let newSize = NSSize(width: 640, height: max(72, height))
            window.setContentSize(newSize)
            self.centerWindow()
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
        // Monitor global mouse clicks to hide window when clicking outside
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, self?.isVisible == true {
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
                            self?.hideWindow()
                        }
                    }
                }
            }
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
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // Cmd+Shift+Space
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
            } else if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                if self?.isVisible == true {
                    DispatchQueue.main.async {
                        self?.hideWindow()
                    }
                }
            }
        }
    }
    
    private func setupLocalHotkey() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // Cmd+Shift+Space
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
                return nil // Consume the event
            } else if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                if self?.isVisible == true {
                    DispatchQueue.main.async {
                        self?.hideWindow()
                    }
                    return nil // Consume the event
                }
            }
            return event
        }
    }
    

    
    private func setupEscapeKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && self?.isVisible == true { // Escape key
                self?.hideWindow()
                return nil // Consume the event
            }
            return event
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
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
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
