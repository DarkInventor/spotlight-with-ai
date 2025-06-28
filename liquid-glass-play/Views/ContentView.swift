import CoreFoundation
import SwiftUI
import GoogleGenerativeAI
import SwiftfulLoadingIndicators

struct ContentView: View {
    @State private var searchText: String = ""
    @State private var response: LocalizedStringKey = "How can I help you today?"
    @State private var responseText: String = "How can I help you today?"
    @State private var isLoading = false
    @State private var isCopied = false
    @State private var selectedImage: NSImage? = nil
    @StateObject private var memoryManager = MemoryManager()
    @State private var showingHotkeyInstructions = false
    @Environment(\.colorScheme) private var colorScheme
    // Before running, please ensure you have added the GoogleGenerativeAI package.
    // In Xcode: File > Add Package Dependencies... > https://github.com/google/generative-ai-swift
    private let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: APIKey.default)

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                SearchBar(text: $searchText, onSubmit: generateResponse, onImageDrop: handleImageDrop)
                    .frame(maxWidth: .infinity)
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
                    VStack {
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

    private func generateResponse() {
        guard !searchText.isEmpty || selectedImage != nil else { return }
        
        // Check if we need to ask for permission first (only once)
        if memoryManager.shouldAskPermission() {
            memoryManager.requestPermission()
            return
        }
        
        isLoading = true
        response = ""
        responseText = ""
        
        let userInput = searchText
        let hasImage = selectedImage != nil

        Task {
            do {
                let result: GenerateContentResponse
                
                // Load recent memory for context
                let memoryContext = memoryManager.loadRecentMemory(limit: 5)
                let contextualPrompt = memoryContext.isEmpty ? userInput : "\(memoryContext)\n\nCurrent question: \(userInput)"
                
                if let image = selectedImage {
                    // Convert NSImage to Data
                    guard let tiffData = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiffData),
                          let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
                        throw NSError(domain: "ImageConversion", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
                    }
                    
                    let prompt = userInput.isEmpty ? "What do you see in this image?" : contextualPrompt
                    let imagePart = ModelContent.Part.data(mimetype: "image/jpeg", jpegData)
                    result = try await model.generateContent(prompt, imagePart)
                    withAnimation {
                        self.selectedImage = nil // Clear image after sending
                    }
                } else {
                    result = try await model.generateContent(contextualPrompt)
                }
                
                let resultText = result.text ?? "No response found"
                response = LocalizedStringKey(resultText)
                responseText = resultText
                
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
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
