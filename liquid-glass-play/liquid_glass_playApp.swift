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
            CommandGroup(replacing: .newItem) {
                // Primary toggle command in File menu
                Button("AI Spotlight") {
                    windowManager.toggleWindow()
                }
                .keyboardShortcut("j", modifiers: .command)
            }
            
            CommandGroup(after: .windowArrangement) {
                // Window menu commands
                WindowCommands(windowManager: windowManager)
            }
        }
    }
}

#if canImport(AppKit)
class WindowManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var isConfigured: Bool = false
    private var window: NSWindow?
    private var statusItem: NSStatusItem?

    
    init() {
        setupMenuBarIcon()
        setupGlobalHotkey()
        
        // Start hidden - only show when hotkey is pressed
        print("🎯 App started. Press Cmd+J to show AI Spotlight")
        print("💡 Keyboard shortcuts work via menu commands (no accessibility permissions needed)")
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
            button.toolTip = "Click or press Cmd+J to open AI Spotlight"
        }
    }
    
    @objc func toggleWindow() {
        if isVisible {
            hideWindow()
        } else {
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
                print("❌ Could not find main window")
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
            
            // Force key window capability
            print("🔍 Window canBecomeKey: \(window.canBecomeKey)")
            print("🔍 Window canBecomeMain: \(window.canBecomeMain)")
            
            // Set initial size - Authentic Spotlight dimensions
            let windowSize = NSSize(width: 640, height: 72)
            window.setContentSize(windowSize)
            
            // Center window
            self.centerWindow()
            
            // Hide window initially
            window.orderOut(nil)
            self.isVisible = false
            
            self.isConfigured = true
            print("🪟 Window configured and hidden. Ready for Cmd+J")
            
            // Setup escape key monitoring once window is ready
            self.setupEscapeKeyMonitor()
        }
    }
    
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { 
                print("❌ No window to show")
                return 
            }
            
            print("👀 Showing AI Spotlight...")
            
            self.isVisible = true
            
            // Center and show window with proper key window setup
            self.centerWindow()
            
            // First check if window can become key
            print("🔍 About to show window - canBecomeKey: \(window.canBecomeKey)")
            
            if window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                print("✅ Window made key successfully")
            } else {
                // Force show even if can't become key, then try to fix it
                window.orderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                print("⚠️ Window can't become key, forcing order front")
                
                // Try to fix key window status
                DispatchQueue.main.async {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            // Aggressive focus strategy - immediate and repeated attempts
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("ForceSelectText"), object: nil)
                
                // Nuclear option: Force focus at AppKit level
                if let contentView = window.contentView {
                    self.findAndFocusTextField(in: contentView)
                }
            }
        }
    }
    
    func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            print("🙈 Hiding AI Spotlight...")
            
            self.isVisible = false
            window.orderOut(nil)
            
            // Clear search when hiding
            NotificationCenter.default.post(name: NSNotification.Name("ClearSearch"), object: nil)
        }
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
        // Check if we have accessibility permissions for global monitoring
        let hasAccessibility = AXIsProcessTrusted()
        
        if hasAccessibility {
            setupNSEventHotkey()
            print("✅ Global hotkey monitoring enabled (accessibility permissions granted)")
        } else {
            print("⚠️ Global hotkey monitoring disabled (no accessibility permissions)")
            print("💡 Menu shortcuts (Cmd+K) will still work when app is focused")
        }
    }
    
    private func setupNSEventHotkey() {
        // NSEvent approach for global hotkeys (requires accessibility permissions)
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                print("🔥 Global hotkey (Cmd+J) detected!")
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
            }
        }
        
        // Also monitor local events for when the app is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.keyCode == 38 { // Cmd+J
                print("🔥 Local hotkey (Cmd+J) detected!")
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
                return nil // Consume the event
            }
            return event
        }
        
        print("⌨️ Global and local hotkey monitors setup complete")
    }
    
    private func setupEscapeKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && self?.isVisible == true { // Escape key
                print("🚫 Escape pressed, hiding window")
                self?.hideWindow()
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func findAndFocusTextField(in view: NSView) {
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                DispatchQueue.main.async {
                    self.window?.makeFirstResponder(textField)
                    textField.selectText(nil)
                    print("🎯 NUCLEAR FOCUS: Found and focused text field directly")
                }
                return
            }
            // Recursively search subviews
            findAndFocusTextField(in: subview)
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
            .keyboardShortcut("j", modifiers: .command)
            
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
