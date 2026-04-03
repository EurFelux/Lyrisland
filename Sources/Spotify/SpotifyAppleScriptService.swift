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
            return trackId & "||" & trackName & "||" & trackArtist & "||" & trackAlbum & "||" & (trackDuration as string) & "||" & (playerPos as string) & "||" & playerState & "||" & artURL
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
        }

        guard error == nil, let raw = result.stringValue, raw != "NOT_RUNNING" else {
            return nil
        }

        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 7 else { return nil }

        let position = Double(parts[5]) ?? 0
        let durationMs = Int(parts[4]) ?? 0
        let isPlaying = parts[6] == "playing"
        let artworkURL = parts.count > 7 ? parts[7] : nil

        return SpotifyPlaybackState(
            trackId: parts[0],
            title: parts[1],
            artist: parts[2],
            album: parts[3],
            durationMs: durationMs,
            position: position,
            isPlaying: isPlaying,
            artworkURL: artworkURL
        )
    }
}
