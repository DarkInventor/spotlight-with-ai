import Foundation
import AVFoundation
import Speech
import SwiftUI

@MainActor
class SpeechManager: NSObject, ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var speechError: String?
    @Published var isSpeaking = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var audioPlayer = AVPlayer()
    private var silenceTimer: Timer?
    private var fullTranscript = ""
    
    private let deepgramAPIKey = APIKey.deepgram
    private let ttsModel = "aura-luna-en"
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    self?.speechError = "Speech recognition access denied"
                case .restricted:
                    self?.speechError = "Speech recognition restricted"
                case .notDetermined:
                    self?.speechError = "Speech recognition not determined"
                @unknown default:
                    self?.speechError = "Unknown speech recognition error"
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        guard !isRecording else { return }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            self.speechError = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
            self.speechError = "Audio engine failed to start"
            return
        }
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    self.recognizedText = newText
                    
                    // Only start/reset the silence timer if we have actual speech content
                    if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("🎤 Speech detected: '\(newText)' - Starting/resetting silence timer")
                        self.resetSilenceTimer()
                    }
                    
                    // If the result is final, update full transcript
                    if result.isFinal {
                        self.fullTranscript = newText
                    }
                }
                
                if let error = error {
                    print("❌ Speech recognition error: \(error)")
                    self.stopRecording()
                }
            }
        }
        
        recognizedText = ""
        fullTranscript = ""
        isRecording = true
        // DON'T start the silence timer immediately - wait for speech to be detected first
        
        print("✅ Speech recognition started - listening for speech...")
    }

    func stopRecording() {
        if isRecording {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            
            isRecording = false
            silenceTimer?.invalidate()
            
            // Finalize the transcript
            let finalText = fullTranscript.isEmpty ? recognizedText : fullTranscript
            recognizedText = finalText
            
            // Post notification for auto-processing
            NotificationCenter.default.post(
                name: NSNotification.Name("AutoProcessSpeech"), 
                object: finalText.isEmpty ? nil : finalText
            )
            
            print("✅ Speech recognition stopped. Final text: '\(finalText)'")
        }
    }

    func cancelRecording() {
        if isRecording {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            
            isRecording = false
            silenceTimer?.invalidate()
            
            // Clear transcripts
            fullTranscript = ""
            recognizedText = ""
            
            print("🎤 Speech recognition cancelled")
        }
    }

    func speak(text: String) {
        guard let url = URL(string: "https://api.deepgram.com/v1/speak?model=\(ttsModel)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(deepgramAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        isSpeaking = true
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isSpeaking = false
                if let error = error {
                    self?.speechError = "TTS Error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.speechError = "TTS Error: No data received"
                    return
                }
                
                self?.playAudio(data: data)
            }
        }
        task.resume()
    }
    
    // MARK: - Private Helpers
    
    private func playAudio(data: Data) {
        do {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
            try data.write(to: tempURL)
            let playerItem = AVPlayerItem(url: tempURL)
            audioPlayer.replaceCurrentItem(with: playerItem)
            audioPlayer.play()
        } catch {
            speechError = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            
            print("🎤 Silence detected (2 seconds), auto-submitting")
            self.stopRecording()
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if available {
                print("✅ Speech recognizer is available")
            } else {
                print("❌ Speech recognizer is not available")
                self.speechError = "Speech recognizer is not available"
            }
        }
    }
} 