import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Habit.order) var habits: [Habit]
    @Query var allEntries: [Entry]
    @Query var allCollections: [Collection]
    @Query var allJournalEntries: [JournalEntry]
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddHabit = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var importResult: DataImporter.ImportResult? = nil
    @State private var showingImportResult = false
    @State private var importError: String? = nil
    @State private var showingImportError = false
    @State private var showingImportFilePicker = false
    
    var isInkwell: Bool { themeManager.current == .inkwell }
    var accent: Color { isInkwell ? InkwellTheme.amber : Color(hex: "#BF5AF2") }
    
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
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
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
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                } footer: {
                    Text("Inkwell uses a warm dark theme inspired by leather-bound books and candlelight.")
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                }
                
                // MARK: - Habits
                Section {
                    ForEach(habits) { habit in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(isInkwell ? 0.12 : 0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        isInkwell
                                        ? Circle().strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                                        : nil
                                    )
                                Image(systemName: habit.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(accent)
                            }
                            Text(habit.name)
                                .font(isInkwell ? .system(.body, design: .serif) : .body)
                                .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                        }
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
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                } footer: {
                    Text("These habits appear on your Today page every day, ready to check off.")
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                }
                
                // MARK: - Data
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                    }
                } header: {
                    Text("About")
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                }
                
                Section {
                    Button {
                        exportData()
                    } label: {
                        if isExporting {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Preparing export...")
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
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
                                    .foregroundStyle(isInkwell ? InkwellTheme.inkPrimary : .primary)
                            }
                        } else {
                            Label("Import Data", systemImage: "arrow.down.doc.fill")
                                .foregroundStyle(accent)
                        }
                    }
                    .disabled(isImporting)
                    
                } header: {
                    Text("Data")
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                } footer: {
                    Text("Export creates a .commonplace archive including all entries, photos, audio, collections, habits, and journal data. Import merges data into your existing library.")
                        .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : .secondary)
                }
            }
            .scrollContentBackground(isInkwell ? .hidden : .visible)
            .background(isInkwell ? InkwellTheme.background : Color(uiColor: .systemGroupedBackground))
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
    
    // MARK: - Export
    
    func exportData() {
        isExporting = true
        Task {
            do {
                let url = try DataExporter.export(
                    entries: allEntries,
                    collections: allCollections,
                    habits: habits,
                    journalEntries: allJournalEntries
                )
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    showingShareSheet = true
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
