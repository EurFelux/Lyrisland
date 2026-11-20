@testable import Lyrisland
import Testing

struct SpotifyAppleScriptServiceTests {
    @Test("Parses a real with a dot decimal separator")
    func dotDecimal() {
        #expect(SpotifyAppleScriptService.parseNumber("288.351") == 288.351)
    }

    @Test("Parses a real with a comma decimal separator from a region like Ukraine")
    func commaDecimal() {
        #expect(SpotifyAppleScriptService.parseNumber("288,351") == 288.351)
    }

    @Test("Parses an integer")
    func integer() {
        #expect(SpotifyAppleScriptService.parseNumber("213000") == 213_000)
    }

    @Test("Ignores surrounding whitespace")
    func whitespace() {
        #expect(SpotifyAppleScriptService.parseNumber(" 12,5 ") == 12.5)
    }

    @Test("Rejects text that is not a number")
    func invalid() {
        #expect(SpotifyAppleScriptService.parseNumber("") == nil)
        #expect(SpotifyAppleScriptService.parseNumber("missing value") == nil)
    }
}
