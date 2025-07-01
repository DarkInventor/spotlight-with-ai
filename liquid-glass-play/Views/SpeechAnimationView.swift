import SwiftUI

struct SpeechAnimationView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            microphoneIcon
            textContent
            Spacer()
            waveAnimation
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 46) // Match SearchBar height for stable layout
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 23)) // Match SearchBar corner radius
    }
    
    // MARK: - Subviews
    
    private var microphoneIcon: some View {
        ZStack {
            Circle()
                .fill(speechManager.isListening ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .animation(.easeInOut(duration: 0.3), value: speechManager.isListening)
            
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(speechManager.isListening ? .red : .blue)
                .animation(.easeInOut(duration: 0.3), value: speechManager.isListening)
        }
        .frame(width: 36, height: 36) // Fixed frame to prevent layout changes
    }
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusText
            recognizedTextView
            errorMessage
        }
    }
    
    private var statusText: some View {
        Text(speechManager.isListening ? "Listening..." : "Tap to speak")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private var recognizedTextView: some View {
        if !speechManager.recognizedText.isEmpty {
            Text(speechManager.recognizedText)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        } else if speechManager.isListening {
            Text("Say something...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .opacity(0.7)
        } else {
            Text("Voice recognition ready")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
    }
    
    @ViewBuilder
    private var errorMessage: some View {
        if let error = speechManager.speechError {
            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.red)
                .lineLimit(2)
        } else if !speechManager.hasPermission {
            Text("Microphone permission required")
                .font(.system(size: 12))
                .foregroundColor(.orange)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private var waveAnimation: some View {
        HStack(spacing: 2) {
            if speechManager.isListening {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 2, height: 8 + (speechManager.animationValue * 6))
                        .animation(.easeInOut(duration: 0.4), value: speechManager.animationValue)
                }
            } else {
                // Static bars when not listening
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2, height: 6)
                }
            }
        }
        .frame(width: 16, height: 16) // Fixed frame to prevent layout jumps
        .padding(.trailing, 8)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 36)
            .fill(colorScheme == .light ? Color.white.opacity(0.4) : Color.clear)
                                .applyLiquidGlass()
            .overlay(
                RoundedRectangle(cornerRadius: 36)
                    .stroke(speechManager.isListening ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: speechManager.isListening ? 2 : 1)
            )
    }
}

#Preview {
    @StateObject var speechManager = SpeechManager()
    
    return VStack(spacing: 20) {
        SpeechAnimationView(speechManager: speechManager)
    }
    .padding()
    .background(Color.black.opacity(0.3))
} 