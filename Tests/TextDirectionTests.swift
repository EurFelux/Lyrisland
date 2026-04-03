@testable import Lyrisland
import Testing

struct TextDirectionTests {
    @Test("Arabic text is detected as RTL")
    func arabicIsRTL() {
        #expect("مرحبا بالعالم".isRTL == true)
    }

    @Test("Hebrew text is detected as RTL")
    func hebrewIsRTL() {
        #expect("שלום עולם".isRTL == true)
    }

    @Test("Persian text is detected as RTL")
    func persianIsRTL() {
        #expect("سلام دنیا".isRTL == true)
    }

    @Test("English text is detected as LTR")
    func englishIsLTR() {
        #expect("Hello World".isRTL == false)
    }

    @Test("Chinese text is detected as LTR")
    func chineseIsLTR() {
        #expect("你好世界".isRTL == false)
    }

    @Test("Japanese text is detected as LTR")
    func japaneseIsLTR() {
        #expect("こんにちは".isRTL == false)
    }

    @Test("Empty string is not RTL")
    func emptyIsNotRTL() {
        #expect("".isRTL == false)
    }

    @Test("Symbols-only string is not RTL")
    func symbolsNotRTL() {
        #expect("♪ ♫ ♬".isRTL == false)
    }
}
