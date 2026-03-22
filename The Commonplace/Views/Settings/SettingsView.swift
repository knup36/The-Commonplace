// SettingsView.swift
// Commonplace
//
// App settings screen presented as a modal sheet.
// Sections: Appearance (theme picker), Daily Habits (add/edit/reorder/delete),
// About (version number), Data (export and import).
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
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Habit.order) var habits: [Habit]
    @Query var allEntries: [Entry]
    @Query var allCollections: [Collection]
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingAddHabit = false
    @State private var habitToEdit: Habit? = nil

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

    // Import state
    @State private var isImporting = false
    @State private var importResult: DataImporter.ImportResult? = nil
    @State private var showingImportResult = false
    @State private var importError: String? = nil
    @State private var showingImportError = false
    @State private var showingImportFilePicker = false

    var style: any AppThemeStyle { themeManager.style }
    var accent: Color { style.accent }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Appearance
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

                // MARK: - Habits
                Section {
                    ForEach(habits) { habit in
                        Button {
                            habitToEdit = habit
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(accent.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            style.usesSerifFonts
                                            ? Circle().strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                                            : nil
                                        )
                                    Image(systemName: habit.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(accent)
                                }
                                Text(habit.name)
                                    .font(style.body)
                                    .foregroundStyle(style.primaryText)
                            }
                        }
                        .foregroundStyle(style.primaryText)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(habits[index])
                        }
                    }
                    .onMove { from, to in
                        var reordered = habits
                        reordered.move(fromOffsets: from, toOffset: to)
                        for (index, habit) in reordered.enumerated() {
                            habit.order = index
                        }
                    }

                    Button {
                        showingAddHabit = true
                    } label: {
                        Label("Add Habit", systemImage: "plus.circle.fill")
                            .foregroundStyle(accent)
                    }
                } header: {
                    Text("Daily Habits")
                        .foregroundStyle(style.tertiaryText)
                } footer: {
                    Text("These habits appear on your Today page every day, ready to check off.")
                        .foregroundStyle(style.tertiaryText)
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(style.primaryText)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(style.tertiaryText)
                    }
                } header: {
                    Text("About")
                        .foregroundStyle(style.tertiaryText)
                }

                // MARK: - Data
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
                        showingImportFilePicker = true
                    } label: {
                        if isImporting {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Importing...")
                                    .foregroundStyle(style.primaryText)
                            }
                        } else {
                            Label("Import Data", systemImage: "arrow.down.doc.fill")
                                .foregroundStyle(accent)
                        }
                    }
                    .disabled(isImporting)

                } header: {
                    Text("Data")
                        .foregroundStyle(style.tertiaryText)
                } footer: {
                    Text("Export creates a .commonplace archive including all entries, photos, audio, collections, habits, and journal data. Import merges data into your existing library.")
                        .foregroundStyle(style.tertiaryText)
                }
            }
            .scrollContentBackground(style.usesSerifFonts ? .hidden : .visible)
            .background(style.usesSerifFonts ? style.background : Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(item: $habitToEdit) { habit in
                AddHabitView(habit: habit)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .fileImporter(
                isPresented: $showingImportFilePicker,
                allowedContentTypes: [.init(filenameExtension: "commonplace") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            // iCloud unsynced files warning
            .alert("Some Files Not Downloaded", isPresented: $showingUnsyncedWarning) {
                Button("Download & Export") {
                    downloadThenExport()
                }
                Button("Export Anyway") {
                    performExport()
                }
                Button("Cancel", role: .cancel) {
                    isExporting = false
                }
            } message: {
                Text("\(unsyncedFileCount) media \(unsyncedFileCount == 1 ? "file is" : "files are") stored in iCloud but not yet downloaded to this device. They will be missing from the export unless you download them first.")
            }
            // Export success summary
            .alert("Export Complete", isPresented: $showingExportSummary) {
                Button("OK", role: .cancel) {}
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
    }

    // MARK: - Export Flow

    /// Entry point when the user taps Export.
    /// Checks for unsynced iCloud files first — warns the user if any are found.
    func startExportFlow() {
        isExporting = true
        exportStatusMessage = "Checking iCloud sync..."
        Task {
            let unsynced = DataExporter.countUnsyncedFiles(entries: allEntries)
            await MainActor.run {
                if unsynced > 0 {
                    unsyncedFileCount = unsynced
                    showingUnsyncedWarning = true
                    // isExporting stays true — spinner stays visible behind the alert
                } else {
                    performExport()
                }
            }
        }
    }

    /// Triggers iCloud download for all pending files, then exports.
    func downloadThenExport() {
        exportStatusMessage = "Downloading files from iCloud..."
        Task {
            let success = await DataExporter.downloadUnsyncedFiles(entries: allEntries)
            await MainActor.run {
                if !success {
                    // Timed out — warn the user but let them proceed
                    importError = "Some files could not be downloaded in time. The export may be incomplete."
                    showingImportError = true
                }
                performExport()
            }
        }
    }

    /// Runs the actual export and shows the share sheet on success.
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
                    showingShareSheet = true
                    // Show summary after share sheet is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingExportSummary = true
                    }
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

    // MARK: - Import

    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                do {
                    let result = try DataImporter.importArchive(from: url, modelContext: modelContext)
                    await MainActor.run {
                        isImporting = false
                        importResult = result
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
