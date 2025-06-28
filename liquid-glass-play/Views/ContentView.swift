import CoreFoundation
import SwiftUI
import GoogleGenerativeAI
import SwiftfulLoadingIndicators

struct ContentView: View {
    @State private var searchText: String = ""
    @State private var response: LocalizedStringKey = "How can I help you today?"
    @State private var isLoading = false
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
                        Text(response)
                            .font(.system(size: 16, weight: .regular))
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                           
                            .glassEffect(in: .rect(cornerRadius: 16.0))
                            
                
                            // .clipShape(RoundedRectangle(cornerRadius: 6))
                            .animation(.easeInOut(duration: 0.3), value: response)
                        
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

        Task {
            do {
                let result = try await model.generateContent(searchText)
                response = LocalizedStringKey(result.text ?? "No response found")
                searchText = ""
            } catch {
                response = "Something went wrong! \n\(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WindowManager())
}
