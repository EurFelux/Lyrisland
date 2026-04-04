import Foundation
@testable import Lyrisland
import Testing

struct KRCDecrypterTests {
    @Test("decrypt returns nil for empty or too-short input")
    func decryptInvalidInput() {
        #expect(KRCDecrypter.decrypt(base64Encoded: "") == nil)
        #expect(KRCDecrypter.decrypt(base64Encoded: "AA==") == nil)
        #expect(KRCDecrypter.decrypt(base64Encoded: "not-valid-base64!!!") == nil)
    }

    @Test("XOR key has 16 bytes")
    func xorKeyLength() {
        #expect(KRCDecrypter.xorKey.count == 16)
    }
}

struct KRCParserTests {
    @Test("parse extracts line timestamps and strips syllable tags")
    func parseBasicKRC() {
        let krc = """
        [0,3000]<0,1000,0>Hello <1000,1000,0>world<2000,1000,0>!
        [3500,2500]<0,1200,0>Second <1200,1300,0>line
        """

        let lines = KRCParser.parse(krc)
        #expect(lines.count == 2)
        #expect(lines[0].time == 0.0)
        #expect(lines[0].text == "Hello world!")
        #expect(lines[1].time == 3.5)
        #expect(lines[1].text == "Second line")
    }

    @Test("parse skips empty lines after tag stripping")
    func parseSkipsEmpty() {
        let krc = """
        [0,1000]<0,1000,0>Hello
        [1000,500]<0,500,0>
        [2000,1000]<0,1000,0>World
        """

        let lines = KRCParser.parse(krc)
        #expect(lines.count == 2)
        #expect(lines[0].text == "Hello")
        #expect(lines[1].text == "World")
    }

    @Test("parse returns sorted lines")
    func parseSorted() {
        let krc = """
        [5000,1000]<0,1000,0>Later
        [1000,1000]<0,1000,0>Earlier
        """

        let lines = KRCParser.parse(krc)
        #expect(lines.count == 2)
        #expect(lines[0].text == "Earlier")
        #expect(lines[1].text == "Later")
    }

    @Test("parse applies translations map")
    func parseWithTranslations() {
        let krc = "[0,2000]<0,1000,0>你好<1000,1000,0>世界"
        let translations: [TimeInterval: String] = [0.0: "Hello World"]

        let lines = KRCParser.parse(krc, translations: translations)
        #expect(lines.count == 1)
        #expect(lines[0].text == "你好世界")
        #expect(lines[0].translation == "Hello World")
    }

    @Test("parse handles lines without syllable tags")
    func parseNoSyllableTags() {
        let krc = "[2000,1000]Plain text line"

        let lines = KRCParser.parse(krc)
        #expect(lines.count == 1)
        #expect(lines[0].text == "Plain text line")
        #expect(lines[0].time == 2.0)
    }
}

struct QQMusicJSONPTests {
    @Test("extractJSON strips JSONP callback wrapper")
    func stripCallback() {
        let jsonp = Data(#"MusicJsonCallback({"lyric":"dGVzdA==","trans":""})"#.utf8)
        let result = QQMusicProvider.extractJSON(from: jsonp)
        let json = try? JSONSerialization.jsonObject(with: result) as? [String: Any]
        #expect(json?["lyric"] as? String == "dGVzdA==")
    }

    @Test("extractJSON strips callback with semicolon")
    func stripCallbackSemicolon() {
        let jsonp = Data(#"callback({"key":"value"});"#.utf8)
        let result = QQMusicProvider.extractJSON(from: jsonp)
        let json = try? JSONSerialization.jsonObject(with: result) as? [String: Any]
        #expect(json?["key"] as? String == "value")
    }

    @Test("extractJSON returns raw JSON unchanged")
    func plainJSON() {
        let plain = Data(#"{"lyric":"test"}"#.utf8)
        let result = QQMusicProvider.extractJSON(from: plain)
        #expect(result == plain)
    }
}
