//
//  SearchBar.swift
//  liquid-glass-play
//
//  Created by Kathan Mehta on 2025-06-27.
//

import SwiftUI
#if canImport(AppKit)
import AppKit

// Custom NSTextField that aggressively accepts focus
class CustomFocusTextField: NSTextField {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Select all text when becoming first responder
        if result {
            DispatchQueue.main.async {
                self.selectText(nil)
            }
        }
        return result
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Note: acceptsFirstResponder is read-only, handled by override above
    }
}
#endif

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFieldFocused: Bool
    let placeholder: String
    let onSubmit: (() -> Void)?
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = CustomFocusTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 24, weight: .regular) // Authentic Spotlight font size
        textField.placeholderString = placeholder
        textField.focusRingType = .none
        textField.textColor = NSColor.labelColor
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 24, weight: .regular)
            ]
        )
        
        // Configure for immediate typing
        textField.refusesFirstResponder = false
        
        // Store reference for focus restoration
        context.coordinator.textField = textField
        
        // Set up notification observer for focus requests
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.handleFocusRequest),
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )
        
        // IMMEDIATE FOCUS - SAVE THE CATS!
        DispatchQueue.main.async {
            if let window = textField.window {
                window.makeFirstResponder(textField)
                textField.selectText(nil)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 24, weight: .regular)
            ]
        )
        
        // Let the .focused view modifier handle focus.
        // Manually managing first responder status here causes the text
        // to be re-selected on every key press.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField
        weak var textField: NSTextField?
        
        init(_ parent: FocusableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // This is invoked when the user presses Enter or the field loses focus.
            // We only care about the Enter key.
            if let textView = obj.object as? NSTextField,
               let reason = obj.userInfo?["NSTextMovement"] as? Int,
               reason == NSReturnTextMovement {
                parent.onSubmit?()
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // This delegate method is not needed for our use case.
            return false
        }
        
        @objc func handleFocusRequest() {
            forceFocus()
        }
        
        func forceFocus() {
            DispatchQueue.main.async { [weak self] in
                if let textField = self?.textField, let window = textField.window {
                    // NUCLEAR FOCUS STRATEGY - SAVE THE CATS!
                    
                    // Force the window to be key first
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Multiple aggressive focus attempts
                    let _ = textField.becomeFirstResponder()
                    window.makeFirstResponder(textField)
                    textField.selectText(nil)
                    self?.parent.isFieldFocused = true
                    
                    // Repeated attempts with increasing delays
                    for delay in [0.01, 0.05, 0.1, 0.2, 0.3] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            if let textField = self?.textField, let window = textField.window {
                                window.makeKeyAndOrderFront(nil)
                                window.makeFirstResponder(textField)
                                let _ = textField.becomeFirstResponder()
                                textField.selectText(nil)
                                self?.parent.isFieldFocused = true
                            }
                        }
                    }
                }
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil
    var onImageDrop: ((NSImage) -> Void)? = nil
    var contextManager: ContextManager? = nil
    @FocusState private var isFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDragOver = false
    @State private var showingImagePicker = false
    @State private var isEditing = false

    
    var body: some View {
        // Spotlight-style pill search bar with refined colors
        HStack(alignment: .center, spacing: 12) {
            // Search bar pill with enhanced styling matching app search results
            HStack(spacing: 10) {
                getCurrentAppIconView()
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .font(.system(size: 22, weight: .medium))
                
                FocusableTextField(
                    text: $text,
                    isFieldFocused: $isFieldFocused,
                    placeholder: "Search...",
                    onSubmit: onSubmit
                )
                .focused($isFieldFocused)
                .font(.system(size: 22, weight: .regular))
                .padding(.vertical, 8)
                
                Spacer(minLength: 0)
                
                // Attach icon for image selection
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .help("Attach image")
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    .background(
                        Circle()
                            .fill(colorScheme == .light ? 
                                  Color.white.opacity(0.8) : 
                                  Color.black.opacity(0.4))
                            .shadow(
                                color: colorScheme == .light ? 
                                       Color.black.opacity(0.08) : 
                                       Color.clear, 
                                radius: 2, 
                                x: 0, 
                                y: 1
                            )
                    )
                    .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(colorScheme == .light ? 
                          Color.white.opacity(0.8) : 
                          Color.black.opacity(0.4))
                    .shadow(
                        color: colorScheme == .light ? 
                               Color.black.opacity(0.10) : 
                               Color.clear, 
                        radius: 16, 
                        x: 0, 
                        y: 6
                    )
            )
            .contentShape(Capsule())
            .frame(height: 48)
            
            // Floating mic button with enhanced styling
            HStack(spacing: 12) {
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("StartSpeechMode"), object: nil)
                }) {
                    Image(systemName: "mic")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(colorScheme == .light ? 
                              Color.white.opacity(0.8) : 
                              Color.black.opacity(0.4))
                        .shadow(
                            color: colorScheme == .light ? 
                                   Color.black.opacity(0.1) : 
                                   Color.clear, 
                            radius: 3, 
                            x: 0, 
                            y: 2
                        )
                )
                .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .onDrop(of: [.image, .fileURL, .data], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusSearchField"))) { _ in
            isFieldFocused = true
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }
    
    @ViewBuilder
    private func getCurrentAppIconView() -> some View {
        if let contextManager = contextManager,
           let context = contextManager.currentContext,
           let appIcon = getCurrentAppIcon(for: context.appName) {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.secondary)
        }
    }
    
    private func getCurrentAppIcon(for appName: String) -> NSImage? {
        if appName.lowercased().contains("searchfast") || 
           appName.lowercased().contains("search") ||
           appName == "Unknown" {
            return nil
        }
        
        if let bundleId = getBundleIdForAppName(appName) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
        
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app"
        ]
        
        for appPath in appPaths {
            if FileManager.default.fileExists(atPath: appPath) {
                return NSWorkspace.shared.icon(forFile: appPath)
            }
        }
        
        return findAppIconByPartialName(appName)
    }
    
    private func getBundleIdForAppName(_ appName: String) -> String? {
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
            "Zoom": "us.zoom.xos",
            "Microsoft Teams": "com.microsoft.teams",
            "TextEdit": "com.apple.TextEdit",
            "Notes": "com.apple.Notes",
            "Notion": "notion.id"
        ]
        
        if let bundleId = bundleIds[appName] {
            return bundleId
        }
        
        let appNameLower = appName.lowercased()
        for (name, bundleId) in bundleIds {
            if name.lowercased().contains(appNameLower) || 
               appNameLower.contains(name.lowercased()) {
                return bundleId
            }
        }
        
        return nil
    }
    
    private func findAppIconByPartialName(_ appName: String) -> NSImage? {
        let appNameLower = appName.lowercased()
        let searchPaths = ["/Applications", "/System/Applications"]
        
        for searchPath in searchPaths {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: searchPath)
                for item in contents {
                    if item.lowercased().contains(appNameLower) && item.hasSuffix(".app") {
                        let fullPath = "\(searchPath)/\(item)"
                        return NSWorkspace.shared.icon(forFile: fullPath)
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Try different type identifiers for maximum compatibility
        let imageTypes = [
            "public.image",
            "public.png",
            "public.jpeg",
            "public.gif",
            "public.tiff",
            "com.apple.pict"
        ]
        
        for provider in providers {
            // First try direct image types
            for imageType in imageTypes {
                if provider.hasItemConformingToTypeIdentifier(imageType) {
                    provider.loadItem(forTypeIdentifier: imageType, options: nil) { item, error in
                        if let data = item as? Data, let image = NSImage(data: data) {
                            DispatchQueue.main.async {
                                onImageDrop?(image)
                            }
                        } else if let url = item as? URL, let image = NSImage(contentsOf: url) {
                            DispatchQueue.main.async {
                                onImageDrop?(image)
                            }
                        }
                    }
                    return true
                }
            }
            
            // Then try file URLs
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let url = item as? URL {
                        let supportedTypes = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic", "heif"]
                        if supportedTypes.contains(url.pathExtension.lowercased()) {
                            if let image = NSImage(contentsOf: url) {
                                DispatchQueue.main.async {
                                    onImageDrop?(image)
                                }
                            }
                        }
                    }
                }
                return true
            }
            
            // Finally try raw data
            if provider.hasItemConformingToTypeIdentifier("public.data") {
                provider.loadItem(forTypeIdentifier: "public.data", options: nil) { item, error in
                    if let data = item as? Data, let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            onImageDrop?(image)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Check if we can access the file
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Load the image
            if let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    onImageDrop?(image)
                }
            }
            
        case .failure(let error):
            print("File selection failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SearchBar(text: .constant(""), contextManager: nil)
        .padding()
} 

 