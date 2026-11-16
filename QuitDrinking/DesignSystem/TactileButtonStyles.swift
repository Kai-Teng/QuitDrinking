import SwiftUI

/// 主行動按鈕樣式（實心飽和底色搭配輕快彈壓回饋）。
struct TactilePrimaryButtonStyle: ButtonStyle {
    var fillColor: Color = ThemeTokens.mintVitality
    var foregroundColor: Color = ThemeTokens.canvasBackground

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeTokens.roundedTitleFont(.headline, weight: .bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                    .fill(fillColor)
            )
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// 次行動按鈕樣式（描邊半透明卡片底色）。
struct TactileOutlineButtonStyle: ButtonStyle {
    var accentColor: Color = ThemeTokens.amberShield

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                    .fill(accentColor.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeTokens.pillRadius, style: .continuous)
                            .strokeBorder(accentColor.opacity(0.55), lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
