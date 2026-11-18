import SwiftUI
import SpriteKit

/// 戰場中可互動的 SpriteKit 怪獸。
struct MonsterAvatarView: View {
    let spec: MonsterSpec
    let hpRatio: Double
    let isStageVisible: Bool
    let hitTrigger: Int
    let shieldTrigger: Int
    var lastDamageAmount: Int = 100
    var lastHealAmount: Int = 45
    var lastHealWasWithinBudget: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene: BattleStageScene?

    private var isPaused: Bool { !isStageVisible || scenePhase != .active }

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(
                    scene: scene,
                    isPaused: isPaused,
                    preferredFramesPerSecond: 60,
                    options: [.allowsTransparency, .shouldCullNonVisibleNodes],
                    shouldRender: { _ in scene.shouldRenderFrame() }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248)
        .onAppear {
            if scene == nil {
                scene = BattleStageScene(size: CGSize(width: 340, height: 250))
            }
            configureScene()
        }
        .onChange(of: spec) { configureScene() }
        .onChange(of: hpRatio) { configureScene() }
        .onChange(of: reduceMotion) { configureScene() }
        .onChange(of: isPaused) { if !isPaused { configureScene() } }
        .onChange(of: hitTrigger) {
            if !isPaused { scene?.triggerAttackVFX(damage: lastDamageAmount) }
        }
        .onChange(of: shieldTrigger) {
            scene?.triggerShieldVFX(healAmount: lastHealAmount, isWithinBudget: lastHealWasWithinBudget)
        }
        .accessibilityRepresentation {
            if reduceMotion {
                Text(spec.name)
                    .accessibilityAddTraits(.isImage)
            } else {
                Button(spec.name) { scene?.pokeMonsterReaction() }
                    .accessibilityHint("與怪獸互動")
            }
        }
        .accessibilityLabel("Lv.\(spec.level) \(spec.name)")
        .accessibilityValue("剩餘血量 \(Int(hpRatio * 100))%")
    }

    private func configureScene() {
        scene?.configure(spec: spec, hpRatio: hpRatio, reduceMotion: reduceMotion)
    }
}
