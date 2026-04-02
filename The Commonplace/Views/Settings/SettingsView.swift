// SettingsView.swift
// Commonplace
//
// App settings screen presented as a full NavigationLink destination from TodayView.
// Does NOT contain its own NavigationStack — it lives inside TodayView's stack.
//
// Sections: Appearance (theme picker), Daily Habits (add/edit/reorder/delete),
// About (version number, what's new), Data (export and import).
//
// Export flow:
//   1. Check if any iCloud media files are not yet downloaded to device
//   2. If unsynced files exist, show a warning alert with options to
//      download first or export anyway
//   3. If downloading, show progress and wait up to 60 seconds
//   4. Run DataExporter.export() and show a summary alert on success
//   5. Open share sheet so user can save the .commonplace archive
//
// Import flow:
//   Opens a file picker for .commonplace files, delegates to DataImporter,
//   and shows a result summary alert.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Habit.order) var habits: [Habit]
    @Query var allEntries: [Entry]
    @Query var allCollections: [Collection]
    @EnvironmentObject var themeManager: ThemeManager
    
    // Habit management moved to HabitSettingsView
    
    // Export state
    @State private var isExporting = false
    @State private var exportURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var exportSummary: String? = nil
    @State private var showingExportSummary = false
    @State private var showingUnsyncedWarning = false
    @State private var unsyncedFileCount = 0
    @State private var isDownloadingFiles = false
    @State private var exportStatusMessage = "Preparing export..."
    @State private var isExportingMarkdown = false
    @State private var markdownExportURL: URL? = nil
    
    // Import state
    @State private var isImporting = false
    @State private var importResult: DataImporter.ImportResult? = nil
    @State private var showingImportResult = false
    @State private var importError: String? = nil
    @State private var showingImportError = false
    @State private var showingImportFilePicker = false
    
    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            appearanceSection
            habitsSection
            aboutSection
            dataSection
        }
        .scrollContentBackground(style.usesSerifFonts ? .hidden : .visible)
        .background(style.usesSerifFonts ? style.background : Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
        // Habit sheets handled in HabitSettingsView
        .fileImporter(
            isPresented: $showingImportFilePicker,
            allowedContentTypes: [.init(filenameExtension: "commonplace") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Some Files Not Downloaded", isPresented: $showingUnsyncedWarning) {
            Button("Download & Export") { downloadThenExport() }
            Button("Export Anyway") { performExport() }
            Button("Cancel", role: .cancel) { isExporting = false }
        } message: {
            Text("\(unsyncedFileCount) media \(unsyncedFileCount == 1 ? "file is" : "files are") stored in iCloud but not yet downloaded to this device. They will be missing from the export unless you download them first.")
        }
        .alert("Ready to Save", isPresented: $showingExportSummary) {
            Button("Save Backup") { showingShareSheet = true }
            Button("Cancel", role: .cancel) { exportURL = nil }
        } message: {
            Text(exportSummary ?? "")
        }
        .alert("Import Complete", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResult?.summary ?? "")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Sections
    
    var appearanceSection: some View {
        Section {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button {
                    themeManager.current = theme
                } label: {
                    HStack {
                        Image(systemName: theme.icon)
                            .foregroundStyle(accent)
                            .frame(width: 24)
                        Text(theme.label)
                            .foregroundStyle(style.primaryText)
                        Spacer()
                        if themeManager.current == theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(accent)
                        }
                    }
                }
            }
        } header: {
            Text("Appearance")
                .foregroundStyle(style.tertiaryText)
        } footer: {
            Text("Inkwell uses a warm dark theme inspired by leather-bound books and candlelight.")
                .foregroundStyle(style.tertiaryText)
        }
    }
    
    var habitsSection: some View {
            Section {
                NavigationLink(destination: HabitSettingsView()) {
                    Label("Daily Habits", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(style.primaryText)
                }
            } header: {
                Text("Habits")
                    .foregroundStyle(style.tertiaryText)
            } footer: {
                Text("Habits appear on your Today page every day, ready to check off.")
                    .foregroundStyle(style.tertiaryText)
            }
        }
    
    var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .foregroundStyle(style.primaryText)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(style.tertiaryText)
            }
            NavigationLink(destination: ReleaseNotesView()) {
                Text("What's New")
                    .foregroundStyle(style.primaryText)
            }
        } header: {
            Text("About")
                .foregroundStyle(style.tertiaryText)
        }
    }
    
    var dataSection: some View {
        Section {
            Button {
                startExportFlow()
            } label: {
                if isExporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(exportStatusMessage)
                            .foregroundStyle(style.primaryText)
                    }
                } else {
                    Label("Export All Data", systemImage: "arrow.up.doc.fill")
                        .foregroundStyle(accent)
                }
            }
            .disabled(isExporting)
            
            Button {
                exportMarkdown()
            } label: {
                if isExportingMarkdown {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Exporting archive...")
                            .foregroundStyle(style.primaryText)
                    }
                } else {
                    Label("Export Markdown Archive", systemImage: "doc.text.fill")
                        .foregroundStyle(accent)
                }
            }
            .disabled(isExportingMarkdown)
            
            Button {
                showingImportFilePicker = true
            } label: {
                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Importing...")
                            .foregroundStyle(style.primaryText)
                    }
                } else {
                    Label("Import Archive", systemImage: "arrow.down.doc.fill")
                        .foregroundStyle(accent)
                }
            }
            .disabled(isImporting)
        } header: {
            Text("Data")
                .foregroundStyle(style.tertiaryText)
        } footer: {
            Text("Export All Data creates a .commonplace archive for backup and restore. Markdown Archive exports a human-readable ZIP for use in Obsidian, Bear, or any text editor.")
                .foregroundStyle(style.tertiaryText)
        }
    }
    
    // MARK: - Export Flow
    
    func startExportFlow() {
        isExporting = true
        exportStatusMessage = "Checking iCloud sync..."
        Task {
            let unsynced = DataExporter.countUnsyncedFiles(entries: allEntries)
            await MainActor.run {
                if unsynced > 0 {
                    unsyncedFileCount = unsynced
                    showingUnsyncedWarning = true
                } else {
                    performExport()
                }
            }
        }
    }
    
    func downloadThenExport() {
        exportStatusMessage = "Downloading files from iCloud..."
        Task {
            let success = await DataExporter.downloadUnsyncedFiles(entries: allEntries)
            await MainActor.run {
                if !success {
                    importError = "Some files could not be downloaded in time. The export may be incomplete."
                    showingImportError = true
                }
                performExport()
            }
        }
    }
    
    func performExport() {
        exportStatusMessage = "Preparing export..."
        Task {
            do {
                let summary = try DataExporter.export(
                    entries: allEntries,
                    collections: allCollections,
                    habits: habits
                )
                await MainActor.run {
                    exportURL = summary.exportURL
                    exportSummary = summary.message
                    isExporting = false
                    showingExportSummary = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    importError = "Export failed: \(error.localizedDescription)"
                    showingImportError = true
                }
            }
        }
    }
    
    func exportMarkdown() {
        isExportingMarkdown = true
        Task {
            do {
                let result = try MarkdownExporter.export(entries: allEntries)
                await MainActor.run {
                    isExportingMarkdown = false
                    markdownExportURL = result.zipURL
                    exportSummary = result.message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let url = result.zipURL
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topVC = rootVC
                            while let presented = topVC.presentedViewController {
                                topVC = presented
                            }
                            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            topVC.present(activityVC, animated: true)
                        }
                    }
                    // Summary shown after share sheet dismisses via onDismiss
                }
            } catch {
                await MainActor.run {
                    isExportingMarkdown = false
                    importError = "Markdown export failed: \(error.localizedDescription)"
                    showingImportError = true
                }
            }
        }
    }
    
    // MARK: - Import
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                do {
                    let importedResult = try DataImporter.importArchive(from: url, modelContext: modelContext)
                    await MainActor.run {
                        isImporting = false
                        importResult = importedResult
                        showingImportResult = true
                    }
                } catch {
                    await MainActor.run {
                        isImporting = false
                        importError = error.localizedDescription
                        showingImportError = true
                    }
                }
            }
        case .failure(let error):
            importError = "Could not open file: \(error.localizedDescription)"
            showingImportError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
