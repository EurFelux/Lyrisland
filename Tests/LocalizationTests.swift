import Foundation
import Testing

struct LocalizationTests {
    /// All languages declared in project.yml must have translations for every string key.
    @Test("Every string key has translations for all supported languages")
    func allKeysHaveAllLanguages() throws {
        let url = Bundle(for: BundleToken.self).url(
            forResource: "Localizable",
            withExtension: "xcstrings"
        ) ?? Bundle.main.url(
            forResource: "Localizable",
            withExtension: "xcstrings"
        )

        // Fall back to reading from source tree for test targets that don't bundle resources
        let fileURL: URL
        if let url {
            fileURL = url
        } else {
            // Walk up from the test bundle to find the project root
            let srcURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Tests/
                .deletingLastPathComponent() // project root
                .appendingPathComponent("Sources/Resources/Localizable.xcstrings")
            fileURL = srcURL
        }

        let data = try Data(contentsOf: fileURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])

        // Collect the union of all languages that appear across any key.
        // This avoids hard-coding the language list — adding a new language
        // to even one key automatically requires it for all keys.
        var allLanguages = Set<String>()
        for (_, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else { continue }
            allLanguages.formUnion(localizations.keys)
        }

        #expect(!allLanguages.isEmpty, "No languages found in xcstrings file")

        var missing: [(key: String, language: String)] = []

        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else {
                for lang in allLanguages {
                    missing.append((key: key, language: lang))
                }
                continue
            }

            for lang in allLanguages where localizations[lang] == nil {
                missing.append((key: key, language: lang))
            }
        }

        if !missing.isEmpty {
            let report = missing
                .sorted { ($0.key, $0.language) < ($1.key, $1.language) }
                .map { "  \($0.key) — missing \($0.language)" }
                .joined(separator: "\n")
            Issue.record("Missing translations:\n\(report)")
        }
    }
}

/// Dummy class used to locate the test bundle.
private final class BundleToken {}
