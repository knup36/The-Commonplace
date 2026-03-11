import SwiftUI
import SwiftData

struct TemplatePickerView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var selectedTemplate: EntryTemplate? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EntryTemplate.all) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            HStack(spacing: 14) {
                                Text(template.emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(Color(uiColor: .systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Choose a Template")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateConfirmView(
                    template: template,
                    navigationPath: $navigationPath,
                    onDismissAll: { dismiss() }
                )
            }
        }
    }
}

struct TemplateConfirmView: View {
    let template: EntryTemplate
    @Binding var navigationPath: NavigationPath
    let onDismissAll: () -> Void
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    var accentColor: Color {
        switch template.type {
        case .text:     return Color(uiColor: .systemGray)
        case .photo:    return .pink
        case .audio:    return .orange
        case .link:     return .blue
        case .journal:  return Color(hex: "#BF5AF2")
        case .location: return .green
        case .sticky:   return Color(hex: "#FFD60A")
        }
    }

    var typeIcon: String {
        switch template.type {
        case .text:     return "text.alignleft"
        case .photo:    return "photo"
        case .audio:    return "waveform"
        case .link:     return "link"
        case .journal:  return "bookmark.fill"
        case .location: return "mappin.circle.fill"
        case .sticky:   return "checklist"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header card
                VStack(spacing: 16) {
                    Text(template.emoji)
                        .font(.system(size: 56))

                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(template.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)

                // Details
                List {
                    Section {
                        HStack {
                            Label("Type", systemImage: typeIcon)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(template.type.rawValue.capitalized)
                                .foregroundStyle(accentColor)
                                .fontWeight(.medium)
                        }

                        if !template.defaultTags.isEmpty {
                            HStack(alignment: .top) {
                                Label("Tags", systemImage: "number")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    ForEach(template.defaultTags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(accentColor.opacity(0.12))
                                            .foregroundStyle(accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxHeight: 200)

                Spacer()

                // Create button
                Button {
                    createEntry()
                } label: {
                    Text("Create Entry")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }

    func createEntry() {
        let entry = Entry(
            type: template.type,
            text: template.defaultText,
            tags: template.defaultTags
        )
        modelContext.insert(entry)

        // Dismiss sheets then navigate
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            onDismissAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                navigationPath.append(entry)
            }
        }
    }
}
