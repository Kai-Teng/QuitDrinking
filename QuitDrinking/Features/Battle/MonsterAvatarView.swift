import SwiftUI
import SpriteKit

/// 破曉戰記 SpriteKit 2D 戰鬥舞台容器（透過原生 SpriteView 承載 BattleStageScene，支援點擊怪獸互動、刀光粒子與護盾穹頂特效）。
struct MonsterAvatarView: View {
    let spec: MonsterSpec
    let hpRatio: Double
    let hitTrigger: Int
    let shieldTrigger: Int
    var lastDamageAmount: Int = 100
    var lastHealAmount: Int = 45
    var lastHealWasWithinBudget: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = BattleStageScene(size: CGSize(width: 340, height: 250))

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 60,
            options: [.allowsTransparency]
        )
        .frame(height: 248)
        .onAppear {
            scene.configure(spec: spec, hpRatio: hpRatio, reduceMotion: reduceMotion)
        }
        .onChange(of: spec) { _, newSpec in
            scene.configure(spec: newSpec, hpRatio: hpRatio, reduceMotion: reduceMotion)
        }
        .onChange(of: hpRatio) { _, newRatio in
            scene.configure(spec: spec, hpRatio: newRatio, reduceMotion: reduceMotion)
        }
        .onChange(of: reduceMotion) { _, newReduce in
            scene.configure(spec: spec, hpRatio: hpRatio, reduceMotion: newReduce)
        }
        .onChange(of: hitTrigger) { _, _ in
            scene.triggerAttackVFX(damage: lastDamageAmount)
        }
        .onChange(of: shieldTrigger) { _, _ in
            scene.triggerShieldVFX(healAmount: lastHealAmount, isWithinBudget: lastHealWasWithinBudget)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lv.\(spec.level) \(spec.name) SpriteKit 戰鬥舞台")
        .accessibilityValue("剩餘血量百分比 \(Int(hpRatio * 100))%")
        .accessibilityHint("點選怪獸可觸發互動反應")
    }
}
