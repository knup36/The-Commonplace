import SwiftUI
import LinkPresentation

struct LinkPreviewView: View {
    let entry: Entry
    @State private var image: UIImage? = nil
    
    var domain: String {
        guard let urlString = entry.url,
              let url = URL(string: urlString),
              let host = url.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            
            // Thumbnail on the left
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Title + domain on the right
            VStack(alignment: .leading, spacing: 4) {
                if let title = entry.linkTitle, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.primary)
                }
                
                HStack(spacing: 4) {
                    if let faviconPath = entry.faviconPath,
                       let faviconData = MediaFileManager.load(path: faviconPath),
                       let favicon = UIImage(data: faviconData) {
                        Image(uiImage: favicon)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            loadImage()
        }
    }
    
    func loadImage() {
        guard image == nil,
              let path = entry.previewImagePath,
              let data = MediaFileManager.load(path: path) else { return }
        image = UIImage(data: data)
    }
}
