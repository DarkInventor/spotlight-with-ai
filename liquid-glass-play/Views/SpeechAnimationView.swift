import SwiftUI

struct SpeechAnimationView: View {
    @ObservedObject var speechManager: SpeechManager
    var onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationValue: Double = 0.0
    @State private var animationTimer: Timer?
    
    var body: some View {
        HStack(spacing: 16) {
            microphoneIcon
            textContent
            Spacer()
            waveAnimation
            cancelButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 46) // Match SearchBar height for stable layout
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 23)) // Match SearchBar corner radius
        .onChange(of: speechManager.isRecording) { _, isRecording in
            if isRecording {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onDisappear(perform: stopAnimation)
    }
    
    // MARK: - Subviews
    
    private var microphoneIcon: some View {
        ZStack {
            Circle()
                .fill(speechManager.isRecording ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2))
                .frame(width: 36, height: 36)
                .animation(.easeInOut(duration: 0.3), value: speechManager.isRecording)
            
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(speechManager.isRecording ? .red : .blue)
                .animation(.easeInOut(duration: 0.3), value: speechManager.isRecording)
        }
        .frame(width: 36, height: 36) // Fixed frame to prevent layout changes
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "keyboard")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, -8)
    }
    
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusText
            recognizedTextView
            errorMessage
        }
    }
    
    private var statusText: some View {
        Text(speechManager.isRecording ? "Listening..." : "Tap to speak")
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
        } else if speechManager.isRecording {
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
        }
    }
    
    @ViewBuilder
    private var waveAnimation: some View {
        HStack(spacing: 2) {
            if speechManager.isRecording {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 2, height: 8 + (animationValue * 12))
                        .animation(.easeInOut(duration: 0.4), value: animationValue)
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
                    .stroke(speechManager.isRecording ? Color.blue.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: speechManager.isRecording ? 2 : 1)
            )
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                self.animationValue = Double.random(in: 0.3...1.0)
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            animationValue = 0.0
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SpeechAnimationView(speechManager: SpeechManager(), onCancel: { print("Cancel tapped") })
    }
    .padding()
    .background(Color.black.opacity(0.3))
} 