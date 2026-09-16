@testable import Lyrisland
import Testing

struct SettingsTabTests {
    @Test("Sidebar lists every category in a stable order")
    func sidebarOrder() {
        #expect(SettingsTab.allCases == [.general, .appearance, .lyrics, .shortcuts, .about])
    }

    @Test("Every category has a localized title and an SF Symbol")
    func titlesAndIcons() {
        for tab in SettingsTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(tab.title != "settings.tab.\(tab.rawValue)", "Missing localization for \(tab.rawValue)")
            #expect(!tab.systemImage.isEmpty)
        }
    }

    @Test("Category identifiers are unique")
    func uniqueIdentifiers() {
        #expect(Set(SettingsTab.allCases.map(\.id)).count == SettingsTab.allCases.count)
    }
}
