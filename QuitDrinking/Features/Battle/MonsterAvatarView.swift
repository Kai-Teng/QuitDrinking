import SwiftUI

/// 破曉戰記向量怪獸舞台（預留團隊美術替換點，並支援受擊震動與誠實護盾特效）。
struct MonsterAvatarView: View {
    let spec: MonsterSpec
    let hpRatio: Double
    let hitTrigger: Int
    let shieldTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var idleBreathing = false
    @State private var showHitFlash = false
    @State private var showShieldDome = false

    private var accentColor: Color {
        Color(hex: spec.accentHex)
    }

    private var isCriticalHP: Bool {
        hpRatio > 0 && hpRatio <= 0.30
    }

    var body: some View {
        let skipMotion = reduceMotion
        ZStack {
            // 怪獸屬性光環
            Circle()
                .fill(accentColor.opacity(isCriticalHP ? 0.14 : 0.22))
                .frame(width: 224, height: 224)
                .scaleEffect(idleBreathing && !skipMotion ? 1.05 : 0.96)
                .animation(
                    skipMotion ? nil : .easeInOut(duration: isCriticalHP ? 1.0 : 2.1).repeatForever(autoreverses: true),
                    value: idleBreathing
                )
                .accessibilityHidden(true)

            // 地台陰影
            Ellipse()
                .fill(Color.black.opacity(0.42))
                .frame(width: 150, height: 26)
                .offset(y: 88)
                .accessibilityHidden(true)

            // 主怪獸圖像（團隊美術替換點：若之後加入 Imageset 如 "monster_lv\(spec.level)" 可於此優先顯示 Image）
            monsterCreatureBody
                .keyframeAnimator(initialValue: HitMotionState(), trigger: hitTrigger) { content, state in
                    content
                        .offset(x: skipMotion ? 0 : state.offsetX, y: skipMotion ? 0 : state.offsetY)
                        .scaleEffect(skipMotion ? 1.0 : state.scale)
                        .rotationEffect(.degrees(skipMotion ? 0 : state.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.offsetX) {
                        SpringKeyframe(-14, duration: 0.06)
                        SpringKeyframe(12, duration: 0.07)
                        SpringKeyframe(-7, duration: 0.07)
                        SpringKeyframe(0, duration: 0.12)
                    }
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(0.88, duration: 0.08)
                        SpringKeyframe(1.04, duration: 0.10)
                        SpringKeyframe(1.0, duration: 0.14)
                    }
                    KeyframeTrack(\.rotation) {
                        SpringKeyframe(-6, duration: 0.07)
                        SpringKeyframe(5, duration: 0.08)
                        SpringKeyframe(0, duration: 0.14)
                    }
                }
                .offset(y: idleBreathing && !skipMotion ? -5 : 4)
                .animation(
                    skipMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: idleBreathing
                )

            // 受擊閃白衝擊波
            if showHitFlash {
                Circle()
                    .strokeBorder(ThemeTokens.mintVitality, lineWidth: 4)
                    .frame(width: 210, height: 210)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .accessibilityHidden(true)
            }

            // 誠實護盾展開特效
            if showShieldDome {
                ZStack {
                    Circle()
                        .fill(ThemeTokens.amberShield.opacity(0.16))
                        .frame(width: 228, height: 228)
                    Circle()
                        .strokeBorder(ThemeTokens.amberShield, lineWidth: 3)
                        .frame(width: 228, height: 228)
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(ThemeTokens.amberShield)
                        .offset(y: -86)
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .accessibilityHidden(true)
            }
        }
        .frame(height: 235)
        .onAppear {
            idleBreathing = true
        }
        .onChange(of: hitTrigger) { _, _ in
            triggerFlash()
        }
        .onChange(of: shieldTrigger) { _, _ in
            triggerShield()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lv.\(spec.level) \(spec.name)")
        .accessibilityValue("剩餘血量百分比 \(Int(hpRatio * 100))%")
    }

    @ViewBuilder
    private var monsterCreatureBody: some View {
        ZStack {
            switch spec.level {
            case 1:
                // Lv.1 微醺史萊姆：半透明氣泡圓頂體
                slimeCreature
            case 2:
                // Lv.2 啤酒肚哥布林：厚重盾牌與啤酒杯角怪
                goblinCreature
            case 3:
                // Lv.3 宿醉巨龍：雙翼與火焰核心
                dragonCreature
            default:
                // Lv.4 心魔魔王：皇冠與裂痕晶體
                demonLordCreature
            }
        }
    }

    private var slimeCreature: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 68, style: .continuous)
                .fill(accentColor.opacity(0.88))
                .frame(width: 146, height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 68, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 2)
                )
            // 氣泡高光
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 22, height: 22)
                .offset(x: -36, y: -30)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 12, height: 12)
                .offset(x: -22, y: -44)
            monsterEyes(eyeSpacing: 46, angry: isCriticalHP)
        }
    }

    private var goblinCreature: some View {
        ZStack {
            // 雙角／尖耳
            HStack(spacing: 112) {
                TriangleEar()
                    .fill(accentColor.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-25))
                TriangleEar()
                    .fill(accentColor.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(25))
            }
            .offset(y: -48)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(ThemeTokens.cardElevated)
                .frame(width: 148, height: 146)
                .overlay(
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .strokeBorder(accentColor, lineWidth: 3)
                )

            VStack(spacing: 10) {
                monsterEyes(eyeSpacing: 44, angry: true)
                Image(systemName: spec.symbolName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var dragonCreature: some View {
        ZStack {
            // 展開雙翼意象
            HStack(spacing: 88) {
                DragonWingShape()
                    .fill(accentColor.opacity(0.72))
                    .frame(width: 56, height: 68)
                DragonWingShape()
                    .fill(accentColor.opacity(0.72))
                    .frame(width: 56, height: 68)
                    .scaleEffect(x: -1, y: 1)
            }
            .offset(y: -14)

            HexagonShape()
                .fill(ThemeTokens.cardElevated)
                .frame(width: 146, height: 152)
                .overlay(
                    HexagonShape()
                        .strokeBorder(accentColor, lineWidth: 3)
                )

            VStack(spacing: 10) {
                monsterEyes(eyeSpacing: 42, angry: true)
                Image(systemName: spec.symbolName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var demonLordCreature: some View {
        ZStack {
            Image(systemName: "crown.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(ThemeTokens.amberShield)
                .offset(y: -86)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .frame(width: 154, height: 154)
                .rotationEffect(.degrees(45))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(accentColor, lineWidth: 3)
                        .rotationEffect(.degrees(45))
                )

            VStack(spacing: 12) {
                monsterEyes(eyeSpacing: 46, angry: true)
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
    }

    private func monsterEyes(eyeSpacing: CGFloat, angry: Bool) -> some View {
        HStack(spacing: eyeSpacing) {
            Capsule()
                .fill(ThemeTokens.inkPrimary)
                .frame(width: 16, height: angry ? 10 : 18)
                .rotationEffect(.degrees(angry ? 16 : 0))
            Capsule()
                .fill(ThemeTokens.inkPrimary)
                .frame(width: 16, height: angry ? 10 : 18)
                .rotationEffect(.degrees(angry ? -16 : 0))
        }
    }

    private func triggerFlash() {
        withAnimation(.easeOut(duration: 0.14)) {
            showHitFlash = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeOut(duration: 0.2)) {
                showHitFlash = false
            }
        }
    }

    private func triggerShield() {
        withAnimation(.easeOut(duration: 0.18)) {
            showShieldDome = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.25)) {
                showShieldDome = false
            }
        }
    }
}

private struct HitMotionState {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1
    var rotation: Double = 0
}

private struct TriangleEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct HexagonShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let points = [
            CGPoint(x: insetRect.midX, y: insetRect.minY),
            CGPoint(x: insetRect.maxX, y: insetRect.minY + insetRect.height * 0.25),
            CGPoint(x: insetRect.maxX, y: insetRect.minY + insetRect.height * 0.75),
            CGPoint(x: insetRect.midX, y: insetRect.maxY),
            CGPoint(x: insetRect.minX, y: insetRect.minY + insetRect.height * 0.75),
            CGPoint(x: insetRect.minX, y: insetRect.minY + insetRect.height * 0.25)
        ]
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

private struct DragonWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.height * 0.55))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.width * 0.55, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
