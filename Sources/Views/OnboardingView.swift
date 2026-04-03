import SwiftUI

/// First-launch onboarding window that guides the user through setup.
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    var onComplete: () -> Void

    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                Text("Lyrisland")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Desktop lyrics in a Dynamic Island")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Steps
            VStack(spacing: 16) {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    spotifyCheckStep
                case 2:
                    permissionStep
                default:
                    readyStep
                }
            }
            .padding(.horizontal, 32)
            .frame(minHeight: 180)

            Spacer()

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button(action: advance) {
                    Text(currentStep >= 3 ? "Get Started" : "Continue")
                        .fontWeight(.medium)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .frame(width: 420, height: 480)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .init(white: 0.1, alpha: 1)))
        )
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("How it works")
            stepItem(icon: "desktopcomputer", text: "Reads playback info from the Spotify desktop app via macOS Automation — no account login needed.")
            stepItem(icon: "text.quote", text: "Fetches synced lyrics from open sources (LRCLIB, Musixmatch, Soda Music).")
            stepItem(icon: "sparkles.rectangle.stack", text: "Displays lyrics in a floating Dynamic Island at the top of your screen.")
        }
    }

    private var spotifyCheckStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("Spotify Desktop App")

            let status = appState.spotifyStatus
            HStack(spacing: 12) {
                Image(systemName: statusIcon(for: status))
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor(for: status))
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle(for: status))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(statusSubtitle(for: status))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))

            if status == .notRunning || status == .notInstalled {
                Button("Open Spotify") {
                    NSWorkspace.shared.open(URL(string: "spotify:")!)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        appState.refresh()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
            }

            Button("Refresh") { appState.refresh() }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
                .font(.system(size: 12))
        }
        .onAppear { appState.refresh() }
    }

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle("Automation Permission")
            stepItem(
                icon: "lock.shield",
                text: "macOS requires your approval to let this app communicate with Spotify."
            )
            stepItem(
                icon: "hand.tap",
                text: "When prompted, click \"OK\" to grant Automation access. You can also enable it in System Settings → Privacy & Security → Automation."
            )

            HStack(spacing: 8) {
                Circle()
                    .fill(appState.permissionStatus == .granted ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(appState.permissionStatus == .granted
                     ? "Permission granted"
                     : "Permission will be requested when Spotify is accessed")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're all set!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                tipItem("Click the island to expand/collapse lyrics")
                tipItem("Use menu bar ♪ icon for settings")
                tipItem("Press [ ] to adjust lyrics timing offset")
            }
        }
    }

    // MARK: - Helpers

    private func advance() {
        if currentStep >= 3 {
            appState.hasCompletedOnboarding = true
            onComplete()
        } else {
            currentStep += 1
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
    }

    private func stepItem(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tipItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text("•").foregroundStyle(.green)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func statusIcon(for status: AppState.SpotifyStatus) -> String {
        switch status {
        case .notInstalled: return "xmark.circle.fill"
        case .notRunning:   return "moon.circle.fill"
        case .running:      return "checkmark.circle.fill"
        }
    }

    private func statusColor(for status: AppState.SpotifyStatus) -> Color {
        switch status {
        case .notInstalled: return .red
        case .notRunning:   return .orange
        case .running:      return .green
        }
    }

    private func statusTitle(for status: AppState.SpotifyStatus) -> String {
        switch status {
        case .notInstalled: return "Spotify not found"
        case .notRunning:   return "Spotify is not running"
        case .running:      return "Spotify is running"
        }
    }

    private func statusSubtitle(for status: AppState.SpotifyStatus) -> String {
        switch status {
        case .notInstalled: return "Please install the Spotify desktop app first."
        case .notRunning:   return "Launch Spotify and play a song to get started."
        case .running:      return "Ready to display lyrics!"
        }
    }
}
