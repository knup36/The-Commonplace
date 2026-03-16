import SwiftUI
import MapKit

struct StickyDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var newItemText = ""
    @State private var isEditingTitle = false
    @State private var editTitle = ""
    @State private var editingItemID: String? = nil
    @State private var editingItemText: String = ""
    @State private var sortedChecked: Set<String> = []
    @FocusState private var newItemFocused: Bool
    @FocusState private var titleFocused: Bool
    @FocusState private var focusedItemID: String?
    
    var isInkwell: Bool { themeManager.current == .inkwell }
    var accentColor: Color { isInkwell ? InkwellTheme.stickyAccent : Color(hex: "#FFD60A") }
    var bgColor: Color { isInkwell ? InkwellTheme.stickyCard : Color(hex: "#FFD60A").opacity(0.15) }
    var isNewEntry: Bool { entry.stickyTitle == nil && entry.text.isEmpty }
    
    struct StickyItem: Identifiable {
        let id: String
        let text: String
    }
    
    var items: [StickyItem] {
        entry.stickyItems.compactMap { raw in
            let parts = raw.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return StickyItem(id: parts[0], text: parts[1])
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleSection
                progressSection
                Divider().overlay(isInkwell ? InkwellTheme.surface : Color.clear)
                itemsList
                Divider().overlay(isInkwell ? InkwellTheme.surface : Color.clear)
                TagInputView(tags: $entry.tags, accentColor: accentColor)
                Divider().overlay(isInkwell ? InkwellTheme.surface : Color.clear)
                metadataFooter
            }
            .padding()
        }
        .background(bgColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sortedChecked = Set(entry.stickyChecked)
            if isNewEntry {
                isEditingTitle = true
                editTitle = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { titleFocused = true }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if newItemFocused || isEditingTitle {
                    Button("Done") {
                        if isEditingTitle {
                            entry.stickyTitle = editTitle.isEmpty ? nil : editTitle
                            isEditingTitle = false
                        }
                        newItemFocused = false
                    }
                    .bold()
                    .foregroundStyle(isInkwell ? InkwellTheme.amber : .primary)
                }
            }
        }
    }
    
    // MARK: - Sub-views
    
    var titleSection: some View {
        Group {
            if isEditingTitle {
                TextField("Title", text: $editTitle)
                    .font(isInkwell ? .system(.title2, design: .serif) : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)
                    .focused($titleFocused)
                    .onSubmit {
                        entry.stickyTitle = editTitle.isEmpty ? nil : editTitle
                        isEditingTitle = false
                    }
            } else {
                Text(entry.stickyTitle ?? "Untitled Sticky")
                    .font(isInkwell ? .system(.title2, design: .serif) : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)
                    .onTapGesture {
                        editTitle = entry.stickyTitle ?? ""
                        isEditingTitle = true
                        titleFocused = true
                    }
            }
        }
    }
    
    @ViewBuilder
    var progressSection: some View {
        if !items.isEmpty {
            HStack(spacing: 8) {
                ProgressView(value: Double(entry.stickyChecked.count), total: Double(items.count))
                    .tint(accentColor)
                Text("\(entry.stickyChecked.count) of \(items.count) completed")
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : .secondary)
            }
        }
    }
    
    var itemsList: some View {
        VStack(spacing: 0) {
            ForEach(items.sorted { !sortedChecked.contains($0.id) && sortedChecked.contains($1.id) }) { item in
                stickyItemRow(item)
                Divider().overlay(isInkwell ? InkwellTheme.surface : Color.clear)
            }
            addItemRow
        }
    }
    
    func stickyItemRow(_ item: StickyItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                            toggleItem(item.id)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    sortedChecked = Set(entry.stickyChecked)
                                }
                            }
                        } label: {
                Image(systemName: entry.stickyChecked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.stickyChecked.contains(item.id)
                                     ? accentColor
                                     : (isInkwell ? InkwellTheme.inkTertiary : Color.secondary))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            
            Text(item.text)
                .font(isInkwell ? .system(.body, design: .serif) : .body)
                .foregroundStyle(entry.stickyChecked.contains(item.id)
                                 ? (isInkwell ? InkwellTheme.inkTertiary : Color.secondary)
                                 : (isInkwell ? InkwellTheme.inkPrimary : Color.primary))
                .strikethrough(entry.stickyChecked.contains(item.id),
                               color: isInkwell ? InkwellTheme.inkTertiary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(focusedItemID == item.id ? 0 : 1)
                .overlay(alignment: .topLeading) {
                    AutoResizingTextEditor(
                        text: focusedItemID == item.id ? $editingItemText : .constant(item.text),
                        minHeight: 28,
                        onSubmit: { saveEditingItem() }
                    )
                    .focused($focusedItemID, equals: item.id)
                    .opacity(focusedItemID == item.id ? 1 : 0)
                    .allowsHitTesting(focusedItemID == item.id)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    saveEditingItem()
                    editingItemText = item.text
                    editingItemID = item.id
                    focusedItemID = item.id
                }
            
            Button { deleteItem(item.id) } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkTertiary : Color(uiColor: .tertiaryLabel))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
    }
    
    var addItemRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(accentColor.opacity(0.6))
                .padding(.top, 4)
            AutoResizingTextEditor(text: $newItemText, placeholder: "Add item...", minHeight: 28, onSubmit: addItem)
                .focused($newItemFocused)
            if !newItemText.isEmpty {
                Button { addItem() } label: {
                    Image(systemName: "return").foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
    }
    
    var metadataFooter: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : Color.secondary)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : Color.secondary)
                if let lat = entry.captureLatitude, let lon = entry.captureLongitude {
                    Button {
                        openInMaps(lat: lat, lon: lon, name: entry.captureLocationName)
                    } label: {
                        Label(entry.captureLocationName ?? "\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(isInkwell ? InkwellTheme.inkSecondary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(accentColor).frame(width: 20, height: 20)
                        Image(systemName: "checklist")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isInkwell ? InkwellTheme.background : .white)
                    }
                    Text("Sticky").font(.caption).foregroundStyle(accentColor)
                }
                .padding(.leading, -3)
                .padding(.top, 3)
            }
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    func toggleItem(_ id: String) {
        if entry.stickyChecked.contains(id) {
            entry.stickyChecked.removeAll { $0 == id }
        } else {
            entry.stickyChecked.append(id)
        }
    }
    
    func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let id = UUID().uuidString
        entry.stickyItems.append("\(id)::\(trimmed)")
        newItemText = ""
        newItemFocused = true
    }
    
    func deleteItem(_ id: String) {
        entry.stickyItems.removeAll { $0.hasPrefix(id) }
        entry.stickyChecked.removeAll { $0 == id }
    }
    
    func saveEditingItem() {
        guard let id = editingItemID else { return }
        let trimmed = editingItemText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            deleteItem(id)
        } else {
            if let index = entry.stickyItems.firstIndex(where: { $0.hasPrefix(id) }) {
                entry.stickyItems[index] = "\(id)::\(trimmed)"
            }
        }
        editingItemID = nil
        editingItemText = ""
    }
    
    func openInMaps(lat: Double, lon: Double, name: String?) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name ?? "Entry Location"
        mapItem.openInMaps()
    }
}
