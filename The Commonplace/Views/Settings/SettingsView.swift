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
    @State private var showingRangeExportSheet = false
    @State private var rangeExportStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var rangeExportEnd: Date = Date()
    @State private var isExportingRange = false
    
    // Import state
    @State private var isImporting = false
    
    // Readwise state
    @State private var readwiseToken: String = ""
    @State private var readwiseTokenSaved: Bool = ReadwiseKeychainService.retrieveToken() != nil
    @State private var isSyncingReadwise: Bool = false
    @State private var readwiseSyncMessage: String? = nil
    @State private var readwiseLastSynced: Date? = UserDefaults.standard.object(forKey: "readwiseLastSyncedAt") as? Date
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
            readwiseSection
            aboutSection
            dataSection
        }
        .scrollContentBackground(.hidden)
        .background(style.background)
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
            Text("Dusk is the default theme. Inkwell uses a warm dark theme inspired by leather-bound books and candlelight.")
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
                showingRangeExportSheet = true
            } label: {
                if isExportingRange {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Exporting...")
                            .foregroundStyle(style.primaryText)
                    }
                } else {
                    Label("Export Markdown — Date Range", systemImage: "calendar.badge.clock")
                        .foregroundStyle(accent)
                }
            }
            .disabled(isExportingRange)
            .sheet(isPresented: $showingRangeExportSheet) {
                rangeExportSheet
            }
            
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
    
    // MARK: - Readwise
    
    var readwiseSection: some View {
        Section {
            if readwiseTokenSaved {
                // Token is stored — show confirmation and option to clear
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("API token saved")
                        .foregroundStyle(style.primaryText)
                    Spacer()
                    Button("Remove") {
                        _ = ReadwiseKeychainService.deleteToken()
                        readwiseTokenSaved = false
                        readwiseToken = ""
                    }
                    .foregroundStyle(.red)
                    .font(.footnote)
                }
                
                // Sync button
                Button {
                    performReadwiseSync()
                } label: {
                    if isSyncingReadwise {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Syncing...")
                                .foregroundStyle(style.primaryText)
                        }
                    } else if let message = readwiseSyncMessage {
                        Label(message, systemImage: "checkmark")
                            .foregroundStyle(.green)
                    } else {
                        Label("Sync Readwise", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(accent)
                    }
                }
                .disabled(isSyncingReadwise)
                
            } else {
                // No token yet — show input field
                SecureField("Paste API token", text: $readwiseToken)
                    .foregroundStyle(style.primaryText)
                
                Button {
                    saveReadwiseToken()
                } label: {
                    Label("Save Token", systemImage: "key.fill")
                        .foregroundStyle(accent)
                }
                .disabled(readwiseToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
        } header: {
            Text("Readwise")
                .foregroundStyle(style.tertiaryText)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Only articles tagged \"commonplace\" in Readwise Reader will be imported.")
                    .foregroundStyle(style.tertiaryText)
                if let lastSynced = readwiseLastSynced {
                    Text("Last synced: \(lastSynced.formatted(.relative(presentation: .named)))")
                        .foregroundStyle(style.tertiaryText)
                        .font(.footnote)
                }
            }
        }
    }
    
    // MARK: - Range Export Sheet
    
    var rangeExportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Start Date",
                        selection: $rangeExportStart,
                        in: ...rangeExportEnd,
                        displayedComponents: .date
                    )
                    .foregroundStyle(style.primaryText)
                    
                    DatePicker(
                        "End Date",
                        selection: $rangeExportEnd,
                        in: rangeExportStart...,
                        displayedComponents: .date
                    )
                    .foregroundStyle(style.primaryText)
                } header: {
                    Text("Date Range")
                        .foregroundStyle(style.tertiaryText)
                } footer: {
                    Text("Exporting entries from \(rangeExportStart.formatted(date: .abbreviated, time: .omitted)) to \(rangeExportEnd.formatted(date: .abbreviated, time: .omitted)).")
                        .foregroundStyle(style.tertiaryText)
                }
                
                Section {
                    Button {
                        performRangeExport()
                    } label: {
                        if isExportingRange {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Exporting...")
                                    .foregroundStyle(style.primaryText)
                            }
                        } else {
                            Label("Export", systemImage: "arrow.up.doc.fill")
                                .foregroundStyle(accent)
                        }
                    }
                    .disabled(isExportingRange)
                }
            }
            .scrollContentBackground(.hidden)
            .background(style.background)
            .navigationTitle("Export Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingRangeExportSheet = false
                    }
                    .foregroundStyle(accent)
                }
            }
        }
    }
    
    func performRangeExport() {
        isExportingRange = true
        Task {
            do {
                let result = try MarkdownExporter.exportRange(
                    entries: allEntries,
                    from: rangeExportStart,
                    to: rangeExportEnd
                )
                await MainActor.run {
                                    isExportingRange = false
                                    showingRangeExportSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                                }
            } catch {
                await MainActor.run {
                    isExportingRange = false
                    if let exportError = error as? MarkdownExportError,
                       exportError == .noEntries {
                        importError = "No entries found in the selected date range."
                    } else {
                        importError = "Export failed: \(error.localizedDescription)"
                    }
                    showingImportError = true
                }
            }
        }
    }
    
    func saveReadwiseToken() {
        let trimmed = readwiseToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let saved = ReadwiseKeychainService.saveToken(trimmed)
        if saved {
            readwiseTokenSaved = true
            readwiseToken = ""
        }
    }
    
    func performReadwiseSync() {
        isSyncingReadwise = true
        readwiseSyncMessage = nil
        
        Task {
            do {
                let service = ReadwiseService()
                let documents = try await service.fetchTaggedDocuments(tag: "commonplace")
                for doc in documents {
                }
                
                let coordinator = ReadwiseSyncCoordinator(
                    modelContext: modelContext,
                    searchIndex: SearchIndex.shared
                )
                let summary = try coordinator.sync(documents: documents)
                
                let syncedAt = Date()
                UserDefaults.standard.set(syncedAt, forKey: "readwiseLastSyncedAt")
                
                await MainActor.run {
                    isSyncingReadwise = false
                    readwiseLastSynced = syncedAt
                    readwiseSyncMessage = summary.displayMessage
                    
                    // Clear the result message after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        readwiseSyncMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isSyncingReadwise = false
                    readwiseSyncMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
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
