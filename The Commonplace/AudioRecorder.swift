import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var recordingTime: TimeInterval = 0
    @Published var transcript: String = ""
    @Published var audioData: Data? = nil
    @Published var errorMessage: String? = nil
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioFileURL: URL?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")
            
            audioFileURL = tempURL
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingTime = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    self.recordingTime += 1
                }
            }
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() async {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        guard let url = audioFileURL else { return }
        audioData = try? Data(contentsOf: url)
        
        await transcribeAudio(url: url)
    }
    
    func transcribeAudio(url: URL) async {
            isTranscribing = true
            
            // Request authorization if needed and wait for it
            if SFSpeechRecognizer.authorizationStatus() != .authorized {
                await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { _ in
                        continuation.resume()
                    }
                }
            }
            
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                errorMessage = "Speech recognition not authorized. Please enable it in Settings."
                isTranscribing = false
                return
            }
        
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            isTranscribing = false
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result, result.isFinal {
                        continuation.resume(returning: result)
                    }
                }
            }
            transcript = result.bestTranscription.formattedString
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
        }
        
        isTranscribing = false
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
