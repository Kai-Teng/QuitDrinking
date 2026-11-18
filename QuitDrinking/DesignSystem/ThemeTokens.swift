import SwiftUI

/// 夜間介面與紙本紀錄共用的語意色彩。
enum ThemeTokens {
    // MARK: - Surfaces & Ink
    static let canvasBackground = Color(hex: 0x0D131F)
    static let cardSurface = Color(hex: 0x162032)
    static let cardElevated = Color(hex: 0x1E293B)
    static let cardStroke = Color.white.opacity(0.08)

    static let inkPrimary = Color(hex: 0xF6F3EC)
    static let inkSecondary = Color(hex: 0x94A3B8)

    // Uncoated paper, dark ink and bottle-green overprint.
    static let receiptPaper = Color(hex: 0xF0E7D2)
    static let receiptInk = Color(hex: 0x282923)
    static let printGreen = Color(hex: 0x2E594D)

    // MARK: - Semantic RPG & Health Accents
    static let mintVitality = Color(hex: 0x2DD4BF)
    static let amberShield = Color(hex: 0xF59E0B)
    static let coralAlert = Color(hex: 0xF43F5E)
    static let skyModeration = Color(hex: 0x38BDF8)
    static let violetBoss = Color(hex: 0xA855F7)

    // MARK: - Layout Radii & Spacing
    static let cardRadius: CGFloat = 12
    static let pillRadius: CGFloat = 8
    static let sectionSpacing: CGFloat = 16

    // MARK: - Typography
    static func printTitleFont(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif, weight: .bold)
    }

    static func roundedNumericFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func roundedTitleFont(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension Color {
    /// 從十六進位色碼建立靜態設計色彩。
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
