import Foundation

/// Raw playback state returned from Spotify via AppleScript.
struct SpotifyPlaybackState {
    let trackId: String
    let title: String
    let artist: String
    let album: String
    let durationMs: Int
    let position: TimeInterval // seconds
    let isPlaying: Bool
    let artworkURL: String?
}

/// Reads Spotify playback state using AppleScript (low-latency, no auth needed).
final class SpotifyAppleScriptService {
    private let script: String = """
    if application "Spotify" is running then
        tell application "Spotify"
            set trackId to id of current track
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set playerPos to player position
            set playerState to player state as string
            set artURL to artwork url of current track
            return {trackId, trackName, trackArtist, trackAlbum, trackDuration, playerPos, playerState, artURL}
        end tell
    else
        return "NOT_RUNNING"
    end if
    """

    private let queue = DispatchQueue(label: "com.lyrisland.applescript", qos: .userInitiated)

    func fetchPlaybackState() async -> SpotifyPlaybackState? {
        await withCheckedContinuation { continuation in
            queue.async { [script] in
                let result = Self.executeScript(script)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Playback Controls

    func playPause() async {
        await executeCommand("playpause")
    }

    func nextTrack() async {
        await executeCommand("next track")
    }

    func previousTrack() async {
        await executeCommand("previous track")
    }

    private func executeCommand(_ command: String) async {
        await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application "Spotify" is running then
                    tell application "Spotify" to \(command)
                end if
                """
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume()
                    return
                }
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error { logDebug("AppleScript command failed: \(error)") }
                continuation.resume()
            }
        }
    }

    /// Synchronous execution on the caller's thread — use only from background context.
    private static func executeScript(_ source: String) -> SpotifyPlaybackState? {
        guard let appleScript = NSAppleScript(source: source) else { return nil }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error {
            logDebug("AppleScript execution failed: \(error)")
            return nil
        }

        return parsePlaybackState(result)
    }

    /// Builds a playback state from the list the script returns.
    ///
    /// The script returns typed values instead of one joined string. `as string` formats numbers for the user's
    /// region: a comma decimal separator (`288,351`), native digits such as Arabic-Indic numerals, or a localized
    /// exponent marker on long tracks. A separator inside a title would also split the fields wrongly.
    ///
    /// Returns `nil` for anything other than the playback list, such as the `"NOT_RUNNING"` text.
    static func parsePlaybackState(_ result: NSAppleEventDescriptor) -> SpotifyPlaybackState? {
        guard result.descriptorType == typeAEList, result.numberOfItems >= 7,
              let trackId = result.atIndex(1)?.stringValue
        else { return nil }

        func text(_ index: Int) -> String? {
            result.atIndex(index)?.stringValue
        }

        // `doubleValue` reads both AppleScript integers and reals; `int32Value` would truncate a real.
        let durationMs = (result.atIndex(5)?.doubleValue).flatMap { Int(exactly: $0.rounded()) } ?? 0

        return SpotifyPlaybackState(
            trackId: trackId,
            title: text(2) ?? "",
            artist: text(3) ?? "",
            album: text(4) ?? "",
            durationMs: durationMs,
            position: result.atIndex(6)?.doubleValue ?? 0,
            isPlaying: text(7) == "playing",
            artworkURL: text(8)
        )
    }
}
