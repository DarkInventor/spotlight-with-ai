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
        
        func forceFocus() {
            DispatchQueue.main.async { [weak self] in
                if let textField = self?.textField, let window = textField.window {
                    window.makeFirstResponder(textField)
                    textField.selectText(nil) // Select all text for immediate typing
                    self?.parent.isFieldFocused = true
                }
            }
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
                            .stroke(isDragOver ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 36)) // Clip the view for rounded corners
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FocusSearchField"))) { _ in
                isFieldFocused = true
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
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
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let url = item as? URL {
                        let supportedTypes = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]
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
        }
        return false
    }
}

#Preview {
    SearchBar(text: .constant(""))
        .padding()
} 

 