import Foundation

/// Fetch status for a single provider's search results.
enum ProviderFetchStatus {
    case loading
    case found([LyricsSearchResult])
    case notFound
    case error(String)
}

/// Observable result container for one provider, used by LyricsPickerView.
@MainActor
final class ProviderResult: ObservableObject, Identifiable {
    let id: String // provider name
    let displayName: String
    @Published var status: ProviderFetchStatus = .loading

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
