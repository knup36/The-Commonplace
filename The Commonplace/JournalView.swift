import SwiftUI

struct JournalView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Journal Coming Soon")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Daily logs and habit tracking will live here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Journal")
        }
    }
}
