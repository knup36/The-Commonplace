// AudioEntryView.swift
// Commonplace
//
// Recording and import UI for audio entries.
// Shown inside AudioDetailSection when entry.audioPath is nil and edit mode is active.
// Contains the record button, timer, transcription progress, and file import option.
//
// Receives style and accentColor from AudioDetailSection so it
// participates in the theme system correctly rather than hardcoding orange.
//
// Updated v2.4 — theme-aware colors replacing hardcoded orange/systemGray.

import SwiftUI
import UniformTypeIdentifiers

struct AudioEntryView: View {
    @StateObject private var recorder = AudioRecorder()
    @Binding var audioPath: String?
    @Binding var transcript: String
    var style: any AppThemeStyle
    var accentColor: Color

    @State private var showingFilePicker = false
    @State private var importedFileName: String? = nil

    var body: some View {
        VStack(spacing: 20) {

            // Timer
            Text(recorder.formatTime(recorder.recordingTime))
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .red : style.cardSecondaryText)

            // Transcribing indicator
            if recorder.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Transcribing...")
                        .font(style.typeBodySecondary)
                        .foregroundStyle(style.cardSecondaryText)
                }
            } else if !recorder.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                    ScrollView {
                        Text(recorder.transcript)
                            .font(style.typeBody)
                            .foregroundStyle(style.cardPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding(10)
                    .background(style.cardDivider)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Imported file name
            if let fileName = importedFileName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(accentColor)
                    Text(fileName)
                        .font(style.typeCaption)
                        .foregroundStyle(style.cardSecondaryText)
                        .lineLimit(1)
                }
            }

            // Error
            if let error = recorder.errorMessage {
                Text(error)
                    .font(style.typeCaption)
                    .foregroundStyle(.red)
            }

            // Record button
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red.opacity(0.15) : accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(accentColor)
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
                        if let data = recorder.audioData {
                            audioPath = try? MediaFileManager.save(data, type: .audio, id: UUID().uuidString)
                        }
                        transcript = recorder.transcript
                    } else {
                        recorder.startRecording()
                    }
                }
            }

            Text(recorder.isRecording ? "Tap to stop" : audioPath != nil ? "Tap to re-record" : "Tap to record")
                .font(style.typeCaption)
                .foregroundStyle(style.cardSecondaryText)

            // Divider
            HStack {
                Rectangle().fill(style.cardDivider).frame(height: 1)
                Text("or")
                    .font(style.typeCaption)
                    .foregroundStyle(style.cardSecondaryText)
                Rectangle().fill(style.cardDivider).frame(height: 1)
            }
            .padding(.horizontal)

            // Import button
            Label("Import Audio File", systemImage: "doc.badge.plus")
                .font(style.typeBodySecondary)
                .foregroundStyle(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    guard !recorder.isRecording && !recorder.isTranscribing else { return }
                    showingFilePicker = true
                }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.audio, UTType.mp3, UTType.mpeg4Audio],
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
            if let data = try? Data(contentsOf: url) {
                audioPath = try? MediaFileManager.save(data, type: .audio, id: UUID().uuidString)
            }

            Task {
                await recorder.transcribeAudio(url: url)
                transcript = recorder.transcript
                if let data = try? Data(contentsOf: url) {
                    audioPath = try? MediaFileManager.save(data, type: .audio, id: UUID().uuidString)
                }
            }

        case .failure(let error):
            recorder.errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
