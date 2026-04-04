import Combine
import SwiftUI

/// ViewModel that aggregates ProviderResult changes into a single observable.
@MainActor
final class LyricsPickerViewModel: ObservableObject {
    let lyricsManager: LyricsManager
    let track: TrackInfo
    @Published var providerResults: [ProviderResult] = []
    private var cancellables: Set<AnyCancellable> = []

    init(lyricsManager: LyricsManager, track: TrackInfo) {
        self.lyricsManager = lyricsManager
        self.track = track
    }

    func startSearch() {
        providerResults = lyricsManager.fetchFromAllProviders(for: track)
        // Forward each result's status changes to trigger view updates
        for result in providerResults {
            result.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    var sortedResults: [LyricsSearchResult] {
        providerResults.flatMap { provider -> [LyricsSearchResult] in
            if case let .found(results) = provider.status { return results }
            return []
        }
        .sorted { $0.score > $1.score }
    }

    var loadingProviders: [ProviderResult] {
        providerResults.filter {
            if case .loading = $0.status { return true }
            return false
        }
    }

    var failedProviders: [ProviderResult] {
        providerResults.filter {
            switch $0.status {
            case .notFound, .error: true
            default: false
            }
        }
    }
}

/// Window view for browsing and selecting lyrics from all providers.
struct LyricsPickerView: View {
    @StateObject private var viewModel: LyricsPickerViewModel

    init(lyricsManager: LyricsManager, track: TrackInfo) {
        _viewModel = StateObject(wrappedValue: LyricsPickerViewModel(
            lyricsManager: lyricsManager, track: track
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: track info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.track.title)
                        .font(.headline)
                    Text(viewModel.track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Divider()

            // Results list — anchor to top so new results don't scroll away from high-score items
            List {
                let allResults = viewModel.sortedResults
                if !allResults.isEmpty {
                    ForEach(allResults) { item in
                        LyricsResultRow(
                            result: item,
                            isSelected: viewModel.lyricsManager.currentLyrics?.source == item.provider
                                && viewModel.lyricsManager.currentLyrics?.lines.count == item.lyrics.lines.count
                        ) {
                            let window = NSApp.keyWindow
                            Task {
                                await viewModel.lyricsManager.applySelectedLyrics(
                                    item.lyrics, fromProvider: item.provider
                                )
                                window?.close()
                            }
                        }
                    }
                }

                // Still-loading providers
                if !viewModel.loadingProviders.isEmpty {
                    Section {
                        ForEach(viewModel.loadingProviders) { provider in
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text(String(localized: "picker.loading \(provider.displayName)"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Error / not-found providers
                if !viewModel.failedProviders.isEmpty {
                    Section {
                        ForEach(viewModel.failedProviders) { provider in
                            HStack {
                                Text(provider.displayName)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                switch provider.status {
                                case .notFound:
                                    Text(String(localized: "picker.not_found"))
                                        .foregroundStyle(.tertiary)
                                case let .error(msg):
                                    Text(msg)
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
                                default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }

                if allResults.isEmpty, viewModel.loadingProviders.isEmpty, !viewModel.failedProviders.isEmpty {
                    Text(String(localized: "picker.no_results"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .defaultScrollAnchor(.top)
        }
        .frame(minWidth: 420, minHeight: 400)
        .preferredColorScheme(.dark)
        .task {
            viewModel.startSearch()
        }
    }
}

// MARK: - Result Row

private struct LyricsResultRow: View {
    let result: LyricsSearchResult
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(ProviderSettings.displayName(for: result.provider))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.15))
                    )

                Text(result.matchInfo)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 12) {
                ScoreBar(score: result.score)
                Text(String(localized: "picker.line_count \(result.lyrics.lines.count)"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(result.lyrics.lines.prefix(3).map(\.text).joined(separator: " / "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Spacer()
                if isSelected {
                    Text(String(localized: "picker.selected"))
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button(String(localized: "picker.select")) {
                        onSelect()
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Score Bar

private struct ScoreBar: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(scoreColor)
                        .frame(width: geo.size.width * min(score / 30.0, 1.0))
                }
            }
            .frame(width: 60, height: 6)

            Text(String(format: "%.0f", score))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var scoreColor: Color {
        switch score {
        case 21...: .green
        case 15...: .blue
        case 8...: .orange
        default: .red
        }
    }
}
