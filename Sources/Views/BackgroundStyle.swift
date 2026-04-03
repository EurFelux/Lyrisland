import Foundation

/// Visual background styles for the Dynamic Island panel.
enum BackgroundStyle: String, CaseIterable, Identifiable {
    case solid
    case albumGradient
    case vibrancy
    case animatedGradient

    var id: String {
        rawValue
    }
}
