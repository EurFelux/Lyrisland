import Foundation

extension String {
    /// Whether the text's base writing direction is right-to-left (e.g. Arabic, Hebrew, Persian).
    /// Uses Core Foundation's language identification on the string content.
    var isRTL: Bool {
        let nsString = self as NSString
        guard nsString.length > 0,
              let language = CFStringTokenizerCopyBestStringLanguage(
                  nsString, CFRange(location: 0, length: nsString.length)
              ) as String?
        else { return false }
        return Locale.Language(identifier: language).characterDirection == .rightToLeft
    }
}
