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
    @FocusState private var isFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDragOver = false
    @State private var showingImagePicker = false

    
    var body: some View {
        if #available(macOS 26.0, *) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .font(.system(size: 18, weight: .medium))
                
                FocusableTextField(
                    text: $text,
                    isFieldFocused: $isFieldFocused,
                    placeholder: "Search...",
                    onSubmit: onSubmit
                )
                .focused($isFieldFocused)

                
                Spacer()
                
                // Attach icon for image selection
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "paperclip")
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Attach image")
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                // Use a RoundedRectangle to ensure the glass effect has rounded corners
                // that match the view's clip shape.
                RoundedRectangle(cornerRadius: 36)
                    .fill(colorScheme == .light ? Color.white.opacity(0.4) : Color.clear)
                    .glassEffect()
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(isDragOver ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isDragOver ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isDragOver)
            )
            .clipShape(RoundedRectangle(cornerRadius: 36)) // Clip the view for rounded corners
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
        } else {
            // Fallback on earlier versions
        }
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
    SearchBar(text: .constant(""))
        .padding()
} 

 