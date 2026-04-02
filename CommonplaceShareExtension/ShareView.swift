// ShareView.swift
// CommonplaceShareExtension
//
// SwiftUI capture UI for the share extension.
// Shows content preview, entry type picker, note field, and tags.
// User picks the entry type — no automatic detection.
// All metadata enrichment happens in the main app via ShareExtensionIngestor.
//
// Type picker shows pre-filtered types based on content, all overridable.
// Suggested type is pre-selected but user can change it.

import SwiftUI
import UIKit
import CoreLocation
import Combine

// MARK: - DoneTextView

struct DoneTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.returnKeyType = .done
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text { textView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: DoneTextView
        init(_ parent: DoneTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" { textView.resignFirstResponder(); return false }
            return true
        }
    }
}

// MARK: - ShareView

struct ShareView: View {
    let suggestedType: String
    let availableTypes: [String]
    let url: String?
    let imageData: Data?
    let initialText: String
    let onSave: (SharedEntry) -> Void
    let onCancel: () -> Void

    @State private var selectedType: String
    @State private var noteText: String = ""
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @StateObject private var locationFetcher = ShareLocationFetcher()

    init(suggestedType: String, availableTypes: [String], url: String?, imageData: Data?, initialText: String, onSave: @escaping (SharedEntry) -> Void, onCancel: @escaping () -> Void) {
        self.suggestedType = suggestedType
        self.availableTypes = availableTypes
        self.url = url
        self.imageData = imageData
        self.initialText = initialText
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedType = State(initialValue: suggestedType)
    }

    // Type display info
    struct TypeOption {
        let type: String
        let label: String
        let icon: String
    }

    let allTypeOptions: [TypeOption] = [
        TypeOption(type: "link",     label: "Link",     icon: "link"),
        TypeOption(type: "photo",    label: "Photo",    icon: "photo.fill"),
        TypeOption(type: "text",     label: "Note",     icon: "text.alignleft"),
        TypeOption(type: "music",    label: "Music",    icon: "music.note"),
        TypeOption(type: "media",    label: "Media",    icon: "film.fill"),
        TypeOption(type: "sticky",   label: "List",     icon: "checklist"),
        TypeOption(type: "location", label: "Place",    icon: "mappin.circle.fill"),
        TypeOption(type: "audio",    label: "Audio",    icon: "waveform"),
    ]

    var visibleOptions: [TypeOption] {
        allTypeOptions.filter { availableTypes.contains($0.type) }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    // Handle bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemGray4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    // Header
                    HStack {
                        Text("Add to Commonplace")
                            .font(.headline)
                        Spacer()
                        Button("Cancel") { onCancel() }
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {

                            // Content preview
                            contentPreview
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                            // Type picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Save as")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)

                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                    spacing: 8
                                ) {
                                    ForEach(visibleOptions, id: \.type) { option in
                                        Button {
                                            selectedType = option.type
                                        } label: {
                                            VStack(spacing: 6) {
                                                Image(systemName: option.icon)
                                                    .font(.system(size: 20, weight: .medium))
                                                Text(option.label)
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 64)
                                            .background(selectedType == option.type
                                                ? Color.accentColor.opacity(0.15)
                                                : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(selectedType == option.type
                                                ? Color.accentColor
                                                : Color(uiColor: .secondaryLabel))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        selectedType == option.type
                                                            ? Color.accentColor.opacity(0.4)
                                                            : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            // Note field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Note")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                DoneTextView(text: $noteText)
                                    .frame(minHeight: 80)
                                    .padding(12)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .padding(.horizontal, 20)
                            }

                            // Tags
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tags")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)

                                if !tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(tags, id: \.self) { tag in
                                                HStack(spacing: 4) {
                                                    Text(tag).font(.caption)
                                                    Button {
                                                        tags.removeAll { $0 == tag }
                                                    } label: {
                                                        Image(systemName: "xmark")
                                                            .font(.system(size: 9, weight: .bold))
                                                    }
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.accentColor.opacity(0.12))
                                                .foregroundStyle(Color.accentColor)
                                                .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }

                                HStack(spacing: 8) {
                                    Image(systemName: "tag")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("Add a tag...", text: $tagInput)
                                        .font(.body)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .onSubmit { addTag() }
                                        .onChange(of: tagInput) { _, newValue in
                                            if newValue.hasSuffix(",") {
                                                tagInput = String(newValue.dropLast())
                                                addTag()
                                            }
                                        }
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal, 20)
                            }

                            // Save button
                            Button { saveEntry() } label: {
                                Text("Save to Commonplace")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -4)
                .frame(maxHeight: geo.size.height * 0.92)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if suggestedType == "text" { noteText = initialText }
            locationFetcher.requestLocation()
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    var contentPreview: some View {
        if let urlString = url {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if !initialText.isEmpty {
            Text(initialText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    func addTag() {
        let cleaned = tagInput
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        guard !cleaned.isEmpty && !tags.contains(cleaned) else {
            tagInput = ""
            return
        }
        tags.append(cleaned)
        tagInput = ""
    }

    func saveEntry() {
        if !tagInput.isEmpty { addTag() }
        let entry = SharedEntry(
            type: selectedType,
            text: noteText,
            url: url,
            imageData: imageData,
            tags: tags,
            captureLatitude: locationFetcher.location?.coordinate.latitude,
            captureLongitude: locationFetcher.location?.coordinate.longitude,
            captureLocationName: locationFetcher.placeName
        )
        onSave(entry)
    }
}

// MARK: - ShareLocationFetcher

class ShareLocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var location: CLLocation? = nil
    @Published var placeName: String? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        self.location = location
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let placemark = placemarks?.first else { return }
                var parts: [String] = []
                if let subLocality = placemark.subLocality {
                    parts.append(subLocality)
                } else if let area = placemark.areasOfInterest?.first {
                    parts.append(area)
                } else if let street = placemark.thoroughfare {
                    parts.append(street)
                }
                if let city = placemark.locality { parts.append(city) }
                if let state = placemark.administrativeArea { parts.append(state) }
                self?.placeName = parts.isEmpty ? placemark.name : parts.joined(separator: ", ")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("ShareLocationFetcher: location failed — \(error.localizedDescription)")
    }
}
