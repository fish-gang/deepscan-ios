import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum OceanTheme {
    // MARK: - Palette
    static let deepOcean = Color(hex: "03045E")
    static let oceanBlue = Color(hex: "0077B6")
    static let aqua      = Color(hex: "00B4D8")
    static let seafoam   = Color(hex: "90E0EF")
    static let foam      = Color(hex: "CAF0F8")
    static let coral     = Color(hex: "FF6B6B")
    static let seagrass  = Color(hex: "52B788")
    static let sandy     = Color(hex: "F4A261")

    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        colors: [deepOcean, oceanBlue, aqua.opacity(0.9)],
        startPoint: .bottom,
        endPoint: .top
    )

    static let primaryButtonGradient = LinearGradient(
        colors: [aqua, oceanBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Helpers
    static func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return seagrass }
        if confidence >= 0.5 { return sandy }
        return coral
    }
}
