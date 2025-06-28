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
    @Environment(\.colorScheme) private var colorScheme
    // Before running, please ensure you have added the GoogleGenerativeAI package.
    // In Xcode: File > Add Package Dependencies... > https://github.com/google/generative-ai-swift
    private let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: APIKey.default)

    var body: some View {
        VStack(spacing: 16) {
            SearchBar(text: $searchText, onSubmit: generateResponse)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

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
    }

    private func generateResponse() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        response = ""
        responseText = ""

        Task {
            do {
                let result = try await model.generateContent(searchText)
                let resultText = result.text ?? "No response found"
                response = LocalizedStringKey(resultText)
                responseText = resultText
                searchText = ""
            } catch {
                let errorText = "Something went wrong! \n\(error.localizedDescription)"
                response = LocalizedStringKey(errorText)
                responseText = errorText
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
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
