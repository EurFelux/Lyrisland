import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var lyricsManager: LyricsManager

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

            LyricsTab(lyricsManager: lyricsManager)
                .tabItem {
                    Label(String(localized: "settings.tab.lyrics"), systemImage: "music.note.list")
                }

            ShortcutsTab()
                .tabItem {
                    Label(String(localized: "settings.tab.shortcuts"), systemImage: "keyboard")
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
    @AppStorage("rootFontSize") private var rootFontSize: Double = 16

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
                HStack {
                    Text(String(localized: "settings.appearance.font_size"))
                    Spacer()
                    Text(String(format: "%.0fpt", rootFontSize))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $rootFontSize, in: 12 ... 24, step: 1)
                if rootFontSize != 16 {
                    HStack {
                        Spacer()
                        Button(String(localized: "settings.appearance.font_size_reset")) {
                            rootFontSize = 16
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text(String(localized: "settings.appearance.font_size_section"))
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
    @ObservedObject var lyricsManager: LyricsManager
    @AppStorage("currentLyricsOffset") private var currentOffset: Double = 0

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "settings.lyrics.providers_section"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 24)

                List {
                    ForEach($lyricsManager.providerSettings.entries) { $entry in
                        HStack {
                            Text(Self.displayName(for: entry.id))
                            Spacer()
                            Toggle("", isOn: $entry.isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 20)

                HStack {
                    Text(String(localized: "settings.lyrics.providers_hint"))
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    Spacer()
                    Button(String(localized: "settings.lyrics.providers_reset")) {
                        lyricsManager.updateProviderSettings(.default)
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 12)
        }
        .onChange(of: lyricsManager.providerSettings) { _, newValue in
            newValue.save()
        }
    }

    private static func displayName(for id: String) -> String {
        ProviderSettings.displayName(for: id)
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    private struct ShortcutEntry: Identifiable {
        let id: String
        let name: KeyboardShortcuts.Name
        let label: LocalizedStringResource
    }

    private let entries: [ShortcutEntry] = [
        ShortcutEntry(id: "toggleLyrics", name: .toggleLyrics, label: "settings.shortcuts.toggle_lyrics"),
        ShortcutEntry(id: "openSettings", name: .openSettings, label: "settings.shortcuts.open_settings"),
        ShortcutEntry(id: "openHelp", name: .openHelp, label: "settings.shortcuts.open_help"),
        ShortcutEntry(id: "quitApp", name: .quitApp, label: "settings.shortcuts.quit_app"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(entries) { entry in
                    KeyboardShortcuts.Recorder(String(localized: entry.label), name: entry.name)
                }
            } header: {
                Text(String(localized: "settings.shortcuts.section"))
            }

            Section {
                HStack {
                    Spacer()
                    Button(String(localized: "settings.shortcuts.reset_all")) {
                        KeyboardShortcuts.reset(KeyboardShortcuts.Name.allCases)
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
