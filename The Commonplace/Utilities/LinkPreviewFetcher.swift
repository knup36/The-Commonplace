import Foundation
import LinkPresentation
import Combine

@MainActor
class LinkPreviewFetcher: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var isLoading = false
    @Published var error: String?
    
    func fetch(urlString: String) async {
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        
        isLoading = true
        error = nil
        
        let provider = LPMetadataProvider()
        
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            self.metadata = metadata
            isLoading = false
        } catch {
            self.error = "Couldn't load preview"
            isLoading = false
        }
    }
}
