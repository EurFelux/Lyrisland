import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label(String(localized: "settings.tab.general"), systemImage: "gearshape")
                }

            AppearanceTab()
                .tabItem {
                    Label(String(localized: "settings.tab.appearance"), systemImage: "paintbrush")
                }

            LyricsTab()
                .tabItem {
                    Label(String(localized: "settings.tab.lyrics"), systemImage: "music.note.list")
                }

            AboutTab()
                .tabItem {
                    Label(String(localized: "settings.tab.about"), systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 380)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @AppStorage("islandPositionMode") private var positionMode = "attached"

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "settings.general.position_mode"), selection: $positionMode) {
                    Text(String(localized: "settings.general.position.attached")).tag("attached")
                    Text(String(localized: "settings.general.position.detached")).tag("detached")
                }
                .pickerStyle(.segmented)
                .onChange(of: positionMode) { _, newValue in
                    guard let mode = IslandPositionMode(rawValue: newValue) else { return }
                    NotificationCenter.default.post(name: .islandPositionModeSettingsChanged, object: mode)
                }
            } header: {
                Text(String(localized: "settings.general.island_section"))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @AppStorage("showArtwork") private var showArtwork = true
    @AppStorage("dualLineMode") private var dualLineMode = false
    @AppStorage("lyricsAlignment") private var lyricsAlignment = "center"
    @AppStorage("backgroundStyle") private var backgroundStyle = "solid"
    @AppStorage("solidColorHex") private var solidColorHex = "#141414"

    private static let defaultSolidHex = "#141414"

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: solidColorHex) ?? Color(white: 0.08) },
            set: { solidColorHex = $0.hexString }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "settings.appearance.background_style"), selection: $backgroundStyle) {
                    Text(String(localized: "settings.appearance.bg.solid")).tag("solid")
                    Text(String(localized: "settings.appearance.bg.album_gradient")).tag("albumGradient")
                    Text(String(localized: "settings.appearance.bg.vibrancy")).tag("vibrancy")
                    Text(String(localized: "settings.appearance.bg.animated_gradient")).tag("animatedGradient")
                }
                .pickerStyle(.radioGroup)

                if backgroundStyle == "solid" {
                    HStack {
                        ColorPicker(
                            String(localized: "settings.appearance.solid_color"),
                            selection: solidColorBinding,
                            supportsOpacity: false
                        )
                        if solidColorHex != Self.defaultSolidHex {
                            Button(String(localized: "settings.appearance.solid_color_reset")) {
                                solidColorHex = Self.defaultSolidHex
                            }
                            .controlSize(.small)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.appearance.background_section"))
            }

            Section {
                Toggle(String(localized: "settings.appearance.show_artwork"), isOn: $showArtwork)
                Toggle(String(localized: "settings.appearance.dual_line"), isOn: $dualLineMode)
                Picker(String(localized: "settings.appearance.lyrics_alignment"), selection: $lyricsAlignment) {
                    Text(String(localized: "settings.appearance.alignment.left")).tag("left")
                    Text(String(localized: "settings.appearance.alignment.center")).tag("center")
                    Text(String(localized: "settings.appearance.alignment.right")).tag("right")
                }
                .pickerStyle(.segmented)
            } header: {
                Text(String(localized: "settings.appearance.display_section"))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Lyrics

private struct LyricsTab: View {
    @AppStorage("currentLyricsOffset") private var currentOffset: Double = 0

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(localized: "settings.lyrics.current_offset"))
                    Spacer()
                    Text(String(format: "%+.1fs", currentOffset))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button(String(localized: "settings.lyrics.offset.earlier")) {
                        NotificationCenter.default.post(name: .lyricsOffsetAdjust, object: -0.5)
                    }
                    Button(String(localized: "settings.lyrics.offset.later")) {
                        NotificationCenter.default.post(name: .lyricsOffsetAdjust, object: 0.5)
                    }
                    Spacer()
                    Button(String(localized: "settings.lyrics.offset.reset")) {
                        NotificationCenter.default.post(name: .lyricsOffsetReset, object: nil)
                    }
                }
                .controlSize(.small)

                Text(String(localized: "settings.lyrics.offset_hint"))
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            } header: {
                Text(String(localized: "settings.lyrics.offset_section"))
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(providerOrder, id: \.self) { name in
                        Text(name)
                    }
                }
            } header: {
                Text(String(localized: "settings.lyrics.providers_section"))
            }
        }
        .formStyle(.grouped)
    }

    /// Keep in sync with LyricsManager.providers
    private var providerOrder: [String] {
        ["LRCLIB", "Musixmatch", "Soda Music", "Netease"]
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Lyrisland")
                .font(.title2.bold())

            Text(String(localized: "settings.about.tagline"))
                .foregroundStyle(.secondary)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                Link(
                    String(localized: "settings.about.github"),
                    destination: URL(string: "https://github.com/EurFelux/Lyrisland")!
                )

                Link(
                    String(localized: "settings.about.issues"),
                    destination: URL(string: "https://github.com/EurFelux/Lyrisland/issues")!
                )
            }
            .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
