import Foundation
import Speech
import AVFoundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

@MainActor
class SpeechManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var speechError: String?
    @Published var hasPermission = false
    @Published var animationValue: Double = 0.0
    @Published var isSpeaking = false
    @Published var autoStopTimer: Timer?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var animationTimer: Timer?
    private var silenceTimer: Timer?
    private var lastSpeechTime = Date()
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    // Constants for auto-stop
    private let silenceTimeout: TimeInterval = 2.0 // 2 seconds of silence
    private let minSpeechLength = 3 // Minimum characters to process
    
            override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        speechSynthesizer.delegate = self
        
        // Request permissions on init
        Task {
            await requestPermissions()
        }
    }
    
    deinit {
        // For deinit, we need to avoid async calls. Just clean up directly.
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        animationTimer?.invalidate()
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async {
        print("🎤 Requesting Speech Recognition Permissions...")
        
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Request microphone permission - using different approach for macOS
        let micStatus: Bool
        #if os(macOS)
        // On macOS, microphone permission is handled by system preferences
        // We'll assume permission is granted if we can create audio engine
        micStatus = true
        #else
        micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #endif
        
        await MainActor.run {
            hasPermission = speechStatus == .authorized && micStatus
            if hasPermission {
                print("✅ Speech permissions granted!")
            } else {
                print("❌ Speech permissions denied")
                speechError = "Speech recognition requires microphone and speech recognition permissions"
            }
        }
    }
    
    // MARK: - Speech Recognition
    
    func startRecording() async {
        guard hasPermission else {
            speechError = "Permission required for speech recognition"
            return
        }
        
        guard !isRecording else { return }
        
        print("🎤 Starting speech recognition...")
        
        do {
            // Stop any existing recording first
            await stopRecordingGracefully()
            
            // Small delay to ensure clean state
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            // Configure audio session - only on iOS
            #if !os(macOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                speechError = "Unable to create recognition request"
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud processing for better accuracy
            
            // Configure audio engine with error handling
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Use smaller buffer size to reduce overload
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // Start audio engine with retry logic
            audioEngine.prepare()
            try audioEngine.start()
            
            // Create recognition task with proper error handling
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let result = result {
                        // Handle successful recognition
                        let transcription = result.bestTranscription.formattedString
                        self.recognizedText = transcription
                        self.lastSpeechTime = Date()
                        print("🎤 Recognized: \(transcription)")
                        
                        // Reset and start silence timer for auto-stop
                        self.resetSilenceTimer()
                        self.startSilenceTimer()
                        
                        // If speech is final and we have meaningful text, prepare to auto-stop
                        if result.isFinal && transcription.count >= self.minSpeechLength {
                            print("🎤 Final result detected - will auto-stop after silence")
                        }
                    }
                    
                    if let error = error {
                        print("❌ Speech recognition error: \(error)")
                        
                        // Handle specific error codes
                        let nsError = error as NSError
                        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                            // Assistant framework conflict - reset and continue
                            print("🔄 Assistant framework conflict detected, resetting...")
                            self.speechError = nil
                            
                            Task {
                                await self.stopRecordingGracefully()
                                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 second
                            }
                        } else if nsError.code == -10877 {
                            // Audio engine error - reset audio session
                            print("🔄 Audio engine error, resetting audio...")
                            self.speechError = nil
                            
                            Task {
                                await self.stopRecordingGracefully()
                            }
                        } else if !error.localizedDescription.contains("canceled") {
                            // Only show error if it's not a cancellation (which is expected)
                            self.speechError = error.localizedDescription
                            self.stopRecording()
                        }
                    }
                }
            }
            
            isRecording = true
            isListening = true
            speechError = nil
            recognizedText = ""
            startSpeechAnimation()
            
            print("✅ Speech recognition started")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            speechError = error.localizedDescription
            stopRecording()
        }
    }
    
    func stopRecording() {
        Task { @MainActor in
            await stopRecordingGracefully()
        }
    }
    
    private func stopRecordingGracefully() async {
        print("🛑 Stopping speech recognition...")
        
        // Stop silence timer
        resetSilenceTimer()
        
        // Stop audio engine gracefully
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap if it exists
        if audioEngine.inputNode.numberOfInputs > 0 {
            do {
                audioEngine.inputNode.removeTap(onBus: 0)
            } catch {
                print("⚠️ Could not remove audio tap: \(error)")
            }
        }
        
        // End recognition gracefully
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.finish()
        recognitionTask = nil
        
        await MainActor.run {
            isRecording = false
            isListening = false
            stopSpeechAnimation()
        }
        
        // Deactivate audio session - only on iOS
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        
        print("✅ Speech recognition stopped")
    }
    
    func cancelRecording() {
        recognizedText = ""
        resetSilenceTimer()
        stopRecording()
    }
    
    // MARK: - Speech Animation
    
    private func startSpeechAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.animationValue = Double.random(in: 0.3...1.0)
                }
            }
        }
    }
    
    private func stopSpeechAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            animationValue = 0.0
        }
    }
    
    // MARK: - Auto-Stop Timer Management
    
    private func startSilenceTimer() {
        resetSilenceTimer()
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Check if we have meaningful speech and enough time has passed
                let speechText = self.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                let timeSinceLastSpeech = Date().timeIntervalSince(self.lastSpeechTime)
                
                if self.isRecording && speechText.count >= self.minSpeechLength && timeSinceLastSpeech >= self.silenceTimeout {
                    print("🎤 Auto-stopping due to silence timeout with text: '\(speechText)'")
                    self.stopRecording()
                    
                    // Post notification to process the speech
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AutoProcessSpeech"),
                        object: speechText
                    )
                }
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    // MARK: - Text-to-Speech
    
    @MainActor
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        print("🗣️ Speaking: \(text)")
        
        // Stop any current speech first
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        isSpeaking = true
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.45 // Slightly slower for clarity and more natural sound
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.75
        
        // Use higher quality voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            // Try to find a premium voice
            let voices = AVSpeechSynthesisVoice.speechVoices()
            if let premiumVoice = voices.first(where: { $0.language == "en-US" && $0.quality == .enhanced }) {
                utterance.voice = premiumVoice
            } else {
                utterance.voice = voice
            }
        }
        
        // Perform speech synthesis on main thread to avoid concurrency issues
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // MARK: - Utility
    
    func clearText() {
        recognizedText = ""
        speechError = nil
        resetSilenceTimer()
    }
    
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable == true
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.hasPermission = available
            print("🎤 Speech recognizer availability changed: \(available)")
        }
    }
}

// MARK: - Speech Recognition Task Handling
// Note: SFSpeechRecognitionTask doesn't support delegates, 
// so we handle everything in the completion handler above

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            print("🗣️ Finished speaking")
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            print("🗣️ Speech canceled")
        }
    }
} 