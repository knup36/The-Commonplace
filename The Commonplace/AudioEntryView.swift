import SwiftUI
import UniformTypeIdentifiers

struct AudioEntryView: View {
    @StateObject private var recorder = AudioRecorder()
    @Binding var audioData: Data?
    @Binding var transcript: String
    @State private var showingFilePicker = false
    @State private var importedFileName: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Timer
            Text(recorder.formatTime(recorder.recordingTime))
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .red : .secondary)
            
            // Status
            if recorder.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Transcribing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if !recorder.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(recorder.transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding(10)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // Imported file name
            if let fileName = importedFileName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.orange)
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Error
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Record button
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 54, height: 54)
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture {
                guard !recorder.isTranscribing && !showingFilePicker else { return }
                Task {
                    if recorder.isRecording {
                        await recorder.stopRecording()
                        audioData = recorder.audioData
                        transcript = recorder.transcript
                    } else {
                        recorder.startRecording()
                    }
                }
            }
            
            Text(recorder.isRecording ? "Tap to stop" : recorder.audioData != nil ? "Tap to re-record" : "Tap to record")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Divider
            HStack {
                Rectangle().fill(Color(uiColor: .systemGray4)).frame(height: 1)
                Text("or").font(.caption).foregroundStyle(.secondary)
                Rectangle().fill(Color(uiColor: .systemGray4)).frame(height: 1)
            }
            .padding(.horizontal)
            
            // Import file button — completely separate from record button
            Label("Import Audio File", systemImage: "doc.badge.plus")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    guard !recorder.isRecording && !recorder.isTranscribing else { return }
                    showingFilePicker = true
                }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                UTType.audio,
                UTType.mp3,
                UTType.mpeg4Audio
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            
            importedFileName = url.lastPathComponent
            audioData = try? Data(contentsOf: url)
            
            Task {
                await recorder.transcribeAudio(url: url)
                transcript = recorder.transcript
                audioData = try? Data(contentsOf: url)
            }
            
        case .failure(let error):
            recorder.errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
