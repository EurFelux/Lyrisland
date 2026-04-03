import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text(String(localized: "help.title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Island Interactions
                helpSection(
                    title: String(localized: "help.section.interactions"),
                    icon: "hand.tap",
                    items: [
                        HelpItem(
                            icon: "cursorarrow.click.2",
                            text: String(localized: "help.interactions.click")
                        ),
                        HelpItem(
                            icon: "hand.point.up.left.and.text",
                            text: String(localized: "help.interactions.longpress")
                        ),
                        HelpItem(
                            icon: "arrow.up.and.down.and.arrow.left.and.right",
                            text: String(localized: "help.interactions.drag")
                        ),
                        HelpItem(
                            icon: "arrow.uturn.up",
                            text: String(localized: "help.interactions.snap")
                        ),
                    ]
                )

                // Settings
                helpSection(
                    title: String(localized: "help.section.settings"),
                    icon: "gearshape",
                    items: [
                        HelpItem(
                            icon: "pin",
                            text: String(localized: "help.settings.position")
                        ),
                        HelpItem(
                            icon: "photo",
                            text: String(localized: "help.settings.artwork")
                        ),
                        HelpItem(
                            icon: "text.line.first.and.arrowtriangle.forward",
                            text: String(localized: "help.settings.dualline")
                        ),
                        HelpItem(
                            icon: "text.alignleft",
                            text: String(localized: "help.settings.alignment")
                        ),
                        HelpItem(
                            icon: "clock.arrow.2.circlepath",
                            text: String(localized: "help.settings.offset")
                        ),
                    ]
                )

                // Keyboard Shortcuts
                helpSection(
                    title: String(localized: "help.section.shortcuts"),
                    icon: "keyboard",
                    items: [
                        HelpItem(
                            icon: "eye",
                            text: String(localized: "help.shortcuts.toggle")
                        ),
                        HelpItem(
                            icon: "gearshape",
                            text: String(localized: "help.shortcuts.settings")
                        ),
                        HelpItem(
                            icon: "questionmark.circle",
                            text: String(localized: "help.shortcuts.help")
                        ),
                        HelpItem(
                            icon: "power",
                            text: String(localized: "help.shortcuts.quit")
                        ),
                    ]
                )

                // Lyrics Providers
                helpSection(
                    title: String(localized: "help.section.providers"),
                    icon: "music.note.list",
                    items: [
                        HelpItem(
                            icon: "text.quote",
                            text: String(localized: "help.providers.chain")
                        ),
                    ]
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 420, height: 480)
    }

    // MARK: - Helpers

    private struct HelpItem {
        let icon: String
        let text: String
    }

    private func helpSection(title: String, icon: String, items: [HelpItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 13))
            }
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 18)
                        Text(item.text)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)
        }
    }
}
