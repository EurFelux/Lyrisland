import Foundation
@testable import Lyrisland
import Testing

/// These tests build the script's result by hand instead of running `NSAppleScript`. The test host is the app,
/// whose poll timer runs AppleScript too, and concurrent `NSAppleScript` executions can hand back each other's results.
struct SpotifyAppleScriptServiceTests {
    /// AppleScript's `missing value`: a type descriptor holding `'msng'`.
    private static let missingValue = NSAppleEventDescriptor(typeCode: 0x6D73_6E67)

    private static func text(_ value: String) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(string: value)
    }

    /// Builds the list the playback script returns, with typed values in the script's field order.
    /// AppleScript returns `duration` as an integer (`long`) and `player position` as a real (`doub`).
    private func playbackList(
        trackId: NSAppleEventDescriptor = text("spotify:track:1"),
        title: NSAppleEventDescriptor = text("Song"),
        artist: NSAppleEventDescriptor = text("Artist"),
        album: NSAppleEventDescriptor = text("Album"),
        duration: NSAppleEventDescriptor = NSAppleEventDescriptor(int32: 213_000),
        position: NSAppleEventDescriptor = NSAppleEventDescriptor(double: 288.351),
        state: String = "playing",
        artworkURL: NSAppleEventDescriptor? = text("https://i.scdn.co/image/abc")
    ) -> NSAppleEventDescriptor {
        let items = [trackId, title, artist, album, duration, position, Self.text(state), artworkURL].compactMap(\.self)
        let list = NSAppleEventDescriptor.list()
        for item in items {
            list.insert(item, at: list.numberOfItems + 1)
        }
        return list
    }

    @Test("Reads every field from the playback list")
    func readsFields() throws {
        let state = try #require(SpotifyAppleScriptService.parsePlaybackState(playbackList()))
        #expect(state.trackId == "spotify:track:1")
        #expect(state.title == "Song")
        #expect(state.artist == "Artist")
        #expect(state.album == "Album")
        #expect(state.durationMs == 213_000)
        #expect(state.position == 288.351)
        #expect(state.isPlaying)
        #expect(state.artworkURL == "https://i.scdn.co/image/abc")
    }

    @Test("Reads a duration that arrives as a real")
    func realDuration() throws {
        let list = playbackList(duration: NSAppleEventDescriptor(double: 213_000))
        let state = try #require(SpotifyAppleScriptService.parsePlaybackState(list))
        #expect(state.durationMs == 213_000)
    }

    @Test("Keeps a title that contains the old field separator")
    func separatorInTitle() throws {
        let list = playbackList(title: Self.text("Intro || Outro"))
        let state = try #require(SpotifyAppleScriptService.parsePlaybackState(list))
        #expect(state.title == "Intro || Outro")
        #expect(state.artist == "Artist")
    }

    @Test("Reports a paused player as not playing")
    func paused() throws {
        let state = try #require(SpotifyAppleScriptService.parsePlaybackState(playbackList(state: "paused")))
        #expect(!state.isPlaying)
    }

    @Test("Treats a missing or absent artwork URL as none")
    func noArtwork() throws {
        for artworkURL in [Self.missingValue, nil] {
            let state = try #require(SpotifyAppleScriptService.parsePlaybackState(playbackList(artworkURL: artworkURL)))
            #expect(state.artworkURL == nil)
        }
    }

    @Test("Reads missing names as empty text")
    func missingNames() throws {
        let list = playbackList(title: Self.missingValue, artist: Self.missingValue, album: Self.missingValue)
        let state = try #require(SpotifyAppleScriptService.parsePlaybackState(list))
        #expect(state.title == "")
        #expect(state.artist == "")
        #expect(state.album == "")
    }

    @Test("Returns nil for a missing track id")
    func missingTrackId() {
        #expect(SpotifyAppleScriptService.parsePlaybackState(playbackList(trackId: Self.missingValue)) == nil)
    }

    @Test("Returns nil for the not-running text")
    func notRunning() {
        #expect(SpotifyAppleScriptService.parsePlaybackState(Self.text("NOT_RUNNING")) == nil)
    }

    @Test("Returns nil for a list that is missing fields")
    func tooShort() {
        let list = NSAppleEventDescriptor.list()
        list.insert(Self.text("spotify:track:1"), at: 1)
        #expect(SpotifyAppleScriptService.parsePlaybackState(list) == nil)
    }
}
