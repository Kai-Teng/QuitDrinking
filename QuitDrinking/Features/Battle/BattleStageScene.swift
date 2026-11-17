import SpriteKit
import SwiftUI
import CoreGraphics

/// 以 SpriteKit 打造的 2D RPG 戰鬥舞台場景（免外部手繪圖檔即可呈現多部件動態怪獸、魔法陣、粒子特效與刀光打擊感；同時支援放入手繪圖無縫替換）。
@MainActor
final class BattleStageScene: SKScene {
    // MARK: - State
    private var currentSpec: MonsterSpec = MonsterCatalog.spec(forLevel: 1)
    private var currentHPRatio: Double = 1.0
    private var reduceMotion: Bool = false

    // MARK: - Scene Graph Nodes
    private let worldNode = SKNode()
    private let bgStarsLayer = SKNode()
    private let magicCircleNode = SKNode()
    private let monsterRootNode = SKNode()
    private let vfxOverlayNode = SKNode()

    private var ambientEmitter: SKEmitterNode?
    private var monsterBubbleEmitter: SKEmitterNode?
    private var isSceneBuilt = false

    // Procedural textures cached once
    private static let softCircleTexture: SKTexture = makeRadialParticleTexture(size: 32, hardEdge: false)
    private static let sparkDiamondTexture: SKTexture = makeDiamondParticleTexture(size: 28)

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        buildSceneIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutNodesForCurrentSize()
    }

    // MARK: - Public Configuration & Triggers

    func configure(spec: MonsterSpec, hpRatio: Double, reduceMotion: Bool) {
        let levelChanged = (spec.level != currentSpec.level) || !isSceneBuilt
        let prevCritical = currentHPRatio <= 0.30 && currentHPRatio > 0
        let nowCritical = hpRatio <= 0.30 && hpRatio > 0

        currentSpec = spec
        currentHPRatio = hpRatio
        self.reduceMotion = reduceMotion

        buildSceneIfNeeded()

        if levelChanged {
            rebuildMagicCircle()
            rebuildAmbientParticles()
            rebuildMonsterRig(animateEntrance: true)
        } else if prevCritical != nowCritical {
            updateMonsterCriticalAura(isCritical: nowCritical)
        }
    }

    func triggerAttackVFX(damage: Int) {
        buildSceneIfNeeded()

        // 1. 對角刀光斬擊弧線
        spawnSwordSlashArc()

        // 2. 粒子爆發火花
        spawnHitSparks(color: skColor(hex: 0x2DD4BF), count: 32)

        // 3. 怪獸受擊後退、閃白與鏡頭震動
        if !reduceMotion {
            runCameraShake(intensity: 9.0, duration: 0.24)
            let recoil = SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 14, y: 10, duration: 0.05),
                    SKAction.scaleX(to: 1.14, y: 0.84, duration: 0.05),
                    SKAction.rotate(byAngle: -0.10, duration: 0.05)
                ]),
                SKAction.group([
                    SKAction.moveBy(x: -22, y: -12, duration: 0.07),
                    SKAction.scaleX(to: 0.90, y: 1.10, duration: 0.07),
                    SKAction.rotate(byAngle: 0.16, duration: 0.07)
                ]),
                SKAction.group([
                    SKAction.move(to: CGPoint(x: 0, y: 8), duration: 0.14),
                    SKAction.scale(to: 1.0, duration: 0.14),
                    SKAction.rotate(toAngle: 0, duration: 0.14)
                ])
            ])
            monsterRootNode.run(recoil, withKey: "hitRecoil")
        }

        // 受擊衝擊光圈
        let shockRing = SKShapeNode(circleOfRadius: 28)
        shockRing.strokeColor = skColor(hex: 0x2DD4BF)
        shockRing.lineWidth = 4.0
        shockRing.fillColor = .clear
        shockRing.position = CGPoint(x: 0, y: 12)
        vfxOverlayNode.addChild(shockRing)
        shockRing.run(.sequence([
            .group([
                .scale(to: 3.4, duration: 0.24),
                .fadeOut(withDuration: 0.24)
            ]),
            .removeFromParent()
        ]))

        // 4. 飄浮暴擊傷害字卡
        let labelText = damage >= 130 ? "-\(damage) 暴擊!" : "-\(damage) HP"
        spawnFloatingCombatText(
            labelText,
            color: skColor(hex: 0x2DD4BF),
            fontSize: damage >= 130 ? 24 : 21,
            startOffset: CGPoint(x: 0, y: 58)
        )
    }

    func triggerShieldVFX(healAmount: Int, isWithinBudget: Bool) {
        buildSceneIfNeeded()

        let shieldHex: UInt32 = isWithinBudget ? 0x38BDF8 : 0xF59E0B
        let tint = skColor(hex: shieldHex)

        // 1. 六角護盾能量穹頂
        let dome = SKShapeNode(path: Self.makeHexagonPath(radius: 92))
        dome.strokeColor = tint
        dome.lineWidth = 3.5
        dome.fillColor = tint.withAlphaComponent(0.16)
        dome.glowWidth = 6.0
        dome.position = CGPoint(x: 0, y: 12)
        dome.setScale(0.75)
        dome.alpha = 0.0
        vfxOverlayNode.addChild(dome)

        // 護盾內部符文環
        let innerRing = SKShapeNode(circleOfRadius: 72)
        innerRing.strokeColor = tint.withAlphaComponent(0.65)
        innerRing.lineWidth = 1.5
        innerRing.fillColor = .clear
        dome.addChild(innerRing)

        dome.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.14),
                .scale(to: 1.04, duration: 0.18)
            ]),
            .scale(to: 0.98, duration: 0.20),
            .wait(forDuration: 0.42),
            .group([
                .fadeOut(withDuration: 0.26),
                .scale(to: 1.12, duration: 0.26)
            ]),
            .removeFromParent()
        ]))

        // 2. 守護光粒上飄
        spawnHitSparks(color: tint, count: 22)

        // 3. 飄浮護盾字卡
        let prefix = isWithinBudget ? "理性小酌" : "誠實護盾"
        spawnFloatingCombatText(
            "\(prefix) +\(healAmount) HP",
            color: tint,
            fontSize: 19,
            startOffset: CGPoint(x: 0, y: 66)
        )
    }

    // MARK: - Touch Interaction (Tap Monster to Poke!)

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: worldNode)
        if hypot(location.x, location.y - 12) <= 105 {
            pokeMonsterReaction()
        }
    }
    #endif

    private func pokeMonsterReaction() {
        spawnHitSparks(color: skColor(hex: currentSpec.accentHex), count: 12)
        guard !reduceMotion else { return }
        let bounce = SKAction.sequence([
            .scaleX(to: 1.12, y: 0.88, duration: 0.07),
            .scaleX(to: 0.94, y: 1.08, duration: 0.09),
            .scale(to: 1.0, duration: 0.12)
        ])
        monsterRootNode.run(bounce, withKey: "pokeBounce")
    }

    // MARK: - Scene Construction

    private func buildSceneIfNeeded() {
        guard !isSceneBuilt else { return }
        isSceneBuilt = true

        addChild(worldNode)
        worldNode.addChild(bgStarsLayer)
        worldNode.addChild(magicCircleNode)
        worldNode.addChild(monsterRootNode)
        worldNode.addChild(vfxOverlayNode)

        buildStarfieldBackdrop()
        rebuildMagicCircle()
        rebuildAmbientParticles()
        rebuildMonsterRig(animateEntrance: false)
        layoutNodesForCurrentSize()
    }

    private func layoutNodesForCurrentSize() {
        magicCircleNode.position = CGPoint(x: 0, y: -74)
        monsterRootNode.position = CGPoint(x: 0, y: 8)
    }

    private func buildStarfieldBackdrop() {
        bgStarsLayer.removeAllChildren()
        let positions: [CGPoint] = [
            CGPoint(x: -118, y: 82), CGPoint(x: -86, y: 44),
            CGPoint(x: 108, y: 76), CGPoint(x: 124, y: 24),
            CGPoint(x: -126, y: -22), CGPoint(x: 92, y: -38),
            CGPoint(x: -44, y: 96), CGPoint(x: 52, y: 92)
        ]
        for (idx, pos) in positions.enumerated() {
            let star = SKSpriteNode(texture: Self.sparkDiamondTexture)
            let dim = CGFloat(idx.isMultiple(of: 2) ? 7 : 5)
            star.size = CGSize(width: dim, height: dim)
            star.position = pos
            star.color = skColor(hex: 0xF6F3EC)
            star.colorBlendFactor = 1.0
            star.alpha = 0.25
            bgStarsLayer.addChild(star)

            if !reduceMotion {
                let twinkle = SKAction.sequence([
                    .fadeAlpha(to: 0.75, duration: Double.random(in: 1.0...1.8)),
                    .fadeAlpha(to: 0.18, duration: Double.random(in: 1.0...1.8))
                ])
                star.run(.repeatForever(twinkle))
            }
        }
    }

    private func rebuildMagicCircle() {
        magicCircleNode.removeAllChildren()
        let accent = skColor(hex: currentSpec.accentHex)

        // 底層暗影橢圓
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 196, height: 48))
        shadow.fillColor = SKColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 0.70)
        shadow.strokeColor = .clear
        magicCircleNode.addChild(shadow)

        // 外層透視魔法陣環
        let outerRing = SKShapeNode(ellipseOf: CGSize(width: 184, height: 42))
        outerRing.fillColor = accent.withAlphaComponent(0.10)
        outerRing.strokeColor = accent.withAlphaComponent(0.65)
        outerRing.lineWidth = 2.0
        outerRing.glowWidth = 4.0
        magicCircleNode.addChild(outerRing)

        // 內層旋轉符文幾何（壓扁形成透視感）
        let runeHolder = SKNode()
        runeHolder.yScale = 0.24
        magicCircleNode.addChild(runeHolder)

        let runeHex = SKShapeNode(path: Self.makeHexagonPath(radius: 68))
        runeHex.strokeColor = accent.withAlphaComponent(0.55)
        runeHex.lineWidth = 2.0
        runeHex.fillColor = .clear
        runeHolder.addChild(runeHex)

        let runeSquare = SKShapeNode(rectOf: CGSize(width: 88, height: 88), cornerRadius: 8)
        runeSquare.strokeColor = accent.withAlphaComponent(0.35)
        runeSquare.lineWidth = 1.5
        runeSquare.fillColor = .clear
        runeSquare.zRotation = .pi / 4
        runeHolder.addChild(runeSquare)

        if !reduceMotion {
            runeHex.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 14.0)))
            runeSquare.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 18.0)))
            let pulse = SKAction.sequence([
                .scale(to: 1.04, duration: 1.4),
                .scale(to: 0.96, duration: 1.4)
            ])
            outerRing.run(.repeatForever(pulse))
        }
    }

    private func rebuildAmbientParticles() {
        ambientEmitter?.removeFromParent()
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.softCircleTexture
        emitter.particleBirthRate = reduceMotion ? 3 : 9
        emitter.particleLifetime = 2.8
        emitter.particleLifetimeRange = 0.8
        emitter.particlePositionRange = CGVector(dx: 160, dy: 20)
        emitter.position = CGPoint(x: 0, y: -70)
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 5
        emitter.particleSpeed = 24
        emitter.particleSpeedRange = 12
        emitter.particleAlpha = 0.55
        emitter.particleAlphaSpeed = -0.18
        emitter.particleScale = 0.22
        emitter.particleScaleRange = 0.12
        emitter.particleScaleSpeed = -0.04
        emitter.particleColor = skColor(hex: currentSpec.accentHex)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        worldNode.insertChild(emitter, at: 2)
        ambientEmitter = emitter
    }

    // MARK: - Multi-Part Procedural Boss Rigs (with Optional Hand-Drawn Override)

    private func rebuildMonsterRig(animateEntrance: Bool) {
        monsterRootNode.removeAllActions()
        monsterRootNode.removeAllChildren()
        monsterBubbleEmitter = nil

        let accent = skColor(hex: currentSpec.accentHex)

        // 背景柔和呼吸光球
        let backGlow = SKSpriteNode(texture: Self.softCircleTexture)
        backGlow.size = CGSize(width: 190, height: 190)
        backGlow.color = accent
        backGlow.colorBlendFactor = 1.0
        backGlow.alpha = 0.28
        backGlow.blendMode = .add
        backGlow.name = "backGlow"
        monsterRootNode.addChild(backGlow)

        // 檢查是否已有組員放入的手繪圖片（例如 Assets.xcassets 中的 "monster_lv1"）
        // 若尚無手繪圖，則使用精緻的多部件程序化 SpriteKit 骨架節點！
        let rigContainer = SKNode()
        rigContainer.name = "rigContainer"
        monsterRootNode.addChild(rigContainer)

        switch currentSpec.level {
        case 1:
            buildLv1SlimeRig(into: rigContainer, accent: accent)
        case 2:
            buildLv2GoblinRig(into: rigContainer, accent: accent)
        case 3:
            buildLv3DragonRig(into: rigContainer, accent: accent)
        default:
            buildLv4DemonLordRig(into: rigContainer, accent: accent)
        }

        if !reduceMotion {
            let floatAction = SKAction.sequence([
                .moveBy(x: 0, y: 9, duration: 1.35),
                .moveBy(x: 0, y: -9, duration: 1.35)
            ])
            rigContainer.run(.repeatForever(floatAction), withKey: "idleFloat")
        }

        if animateEntrance && !reduceMotion {
            monsterRootNode.setScale(0.65)
            monsterRootNode.alpha = 0.0
            monsterRootNode.run(.group([
                .fadeIn(withDuration: 0.22),
                .sequence([
                    .scale(to: 1.08, duration: 0.18),
                    .scale(to: 1.0, duration: 0.12)
                ])
            ]))
        } else {
            monsterRootNode.setScale(1.0)
            monsterRootNode.alpha = 1.0
        }

        updateMonsterCriticalAura(isCritical: currentHPRatio <= 0.30 && currentHPRatio > 0)
    }

    /// Lv.1 微醺史萊姆：雙層半透明果凍軀幹＋內部發光氣泡粒子＋Q 彈呼吸擠壓＋眨眼動畫
    private func buildLv1SlimeRig(into container: SKNode, accent: SKColor) {
        let bodyPath = CGPath(
            roundedRect: CGRect(x: -66, y: -56, width: 132, height: 116),
            cornerWidth: 56,
            cornerHeight: 56,
            transform: nil
        )
        let outerBody = SKShapeNode(path: bodyPath)
        outerBody.fillColor = accent.withAlphaComponent(0.88)
        outerBody.strokeColor = SKColor.white.withAlphaComponent(0.45)
        outerBody.lineWidth = 2.5
        outerBody.glowWidth = 2.0
        container.addChild(outerBody)

        // 史萊姆內部微光果凍核
        let innerCore = SKShapeNode(ellipseOf: CGSize(width: 92, height: 74))
        innerCore.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 0.45)
        innerCore.strokeColor = .clear
        innerCore.position = CGPoint(x: 0, y: -4)
        outerBody.addChild(innerCore)

        // 左上果凍高光
        let highlightBig = SKShapeNode(circleOfRadius: 11)
        highlightBig.fillColor = SKColor.white.withAlphaComponent(0.45)
        highlightBig.strokeColor = .clear
        highlightBig.position = CGPoint(x: -32, y: 26)
        outerBody.addChild(highlightBig)

        let highlightSmall = SKShapeNode(circleOfRadius: 5.5)
        highlightSmall.fillColor = SKColor.white.withAlphaComponent(0.32)
        highlightSmall.strokeColor = .clear
        highlightSmall.position = CGPoint(x: -18, y: 38)
        outerBody.addChild(highlightSmall)

        // 頭頂微醺氣泡粒子發射器
        let bubbles = SKEmitterNode()
        bubbles.particleTexture = Self.softCircleTexture
        bubbles.particleBirthRate = reduceMotion ? 2 : 5
        bubbles.particleLifetime = 1.8
        bubbles.particlePositionRange = CGVector(dx: 70, dy: 20)
        bubbles.position = CGPoint(x: 0, y: 18)
        bubbles.emissionAngle = .pi / 2
        bubbles.emissionAngleRange = .pi / 6
        bubbles.particleSpeed = 28
        bubbles.particleAlpha = 0.65
        bubbles.particleAlphaSpeed = -0.32
        bubbles.particleScale = 0.28
        bubbles.particleScaleSpeed = 0.08
        bubbles.particleColor = SKColor.white
        bubbles.particleColorBlendFactor = 1.0
        outerBody.addChild(bubbles)
        monsterBubbleEmitter = bubbles

        // 表情五官（支援眨眼）
        let faceNode = makeExpressiveFace(eyeSpacing: 42, angry: false, cheekColor: skColor(hex: 0xF43F5E))
        faceNode.position = CGPoint(x: 0, y: -2)
        outerBody.addChild(faceNode)

        if !reduceMotion {
            let squashStretch = SKAction.sequence([
                .scaleX(to: 1.06, y: 0.94, duration: 0.95),
                .scaleX(to: 0.95, y: 1.06, duration: 0.95)
            ])
            outerBody.run(.repeatForever(squashStretch))
        }
    }

    /// Lv.2 啤酒肚哥布林：重裝鎧甲軀幹＋尖角頭盔＋左右獨立懸浮手甲（舉酒杯＆圓盾）
    private func buildLv2GoblinRig(into container: SKNode, accent: SKColor) {
        // 左右尖耳／角
        for side in [-1.0, 1.0] {
            let hornPath = CGMutablePath()
            hornPath.move(to: CGPoint(x: 0, y: 20))
            hornPath.addLine(to: CGPoint(x: side * 34, y: 42))
            hornPath.addLine(to: CGPoint(x: side * 14, y: -4))
            hornPath.closeSubpath()
            let horn = SKShapeNode(path: hornPath)
            horn.fillColor = accent.withAlphaComponent(0.85)
            horn.strokeColor = SKColor.white.withAlphaComponent(0.3)
            horn.lineWidth = 1.5
            horn.position = CGPoint(x: side * 44, y: 34)
            container.addChild(horn)
        }

        // 重裝軀幹
        let torso = SKShapeNode(rectOf: CGSize(width: 126, height: 120), cornerRadius: 38)
        torso.fillColor = skColor(hex: 0x1E293B)
        torso.strokeColor = accent
        torso.lineWidth = 3.0
        torso.glowWidth = 2.0
        container.addChild(torso)

        // 鎧甲胸口護紋
        let belt = SKShapeNode(rectOf: CGSize(width: 112, height: 18), cornerRadius: 6)
        belt.fillColor = skColor(hex: 0x0F172A)
        belt.strokeColor = skColor(hex: 0xF59E0B)
        belt.lineWidth = 1.5
        belt.position = CGPoint(x: 0, y: -26)
        torso.addChild(belt)

        let buckle = SKShapeNode(rectOf: CGSize(width: 22, height: 22), cornerRadius: 5)
        buckle.fillColor = skColor(hex: 0xF59E0B)
        buckle.strokeColor = .clear
        belt.addChild(buckle)

        // 哥布林眼神
        let face = makeExpressiveFace(eyeSpacing: 40, angry: true, cheekColor: nil)
        face.position = CGPoint(x: 0, y: 16)
        torso.addChild(face)

        // 左手：獨立擺動的啤酒木桶杯
        let mugHand = SKNode()
        mugHand.position = CGPoint(x: -78, y: -6)
        container.addChild(mugHand)

        let mugBody = SKShapeNode(rectOf: CGSize(width: 30, height: 38), cornerRadius: 6)
        mugBody.fillColor = skColor(hex: 0xF59E0B)
        mugBody.strokeColor = SKColor.white.withAlphaComponent(0.6)
        mugBody.lineWidth = 2.0
        mugHand.addChild(mugBody)

        let foam = SKShapeNode(ellipseOf: CGSize(width: 34, height: 14))
        foam.fillColor = .white
        foam.strokeColor = .clear
        foam.position = CGPoint(x: 0, y: 18)
        mugBody.addChild(foam)

        // 右手：重裝鉚釘圓盾
        let shieldHand = SKNode()
        shieldHand.position = CGPoint(x: 78, y: -10)
        container.addChild(shieldHand)

        let buckler = SKShapeNode(circleOfRadius: 24)
        buckler.fillColor = skColor(hex: 0x0F172A)
        buckler.strokeColor = accent
        buckler.lineWidth = 3.0
        shieldHand.addChild(buckler)

        if !reduceMotion {
            mugHand.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 10, duration: 0.75),
                .moveBy(x: 0, y: -10, duration: 0.75)
            ])))
            shieldHand.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: -8, duration: 0.85),
                .moveBy(x: 0, y: 8, duration: 0.85)
            ])))
        }
    }

    /// Lv.3 宿醉巨龍：左右獨立拍動龍翼＋六角黑曜鱗甲＋龍角＋火焰核心
    private func buildLv3DragonRig(into container: SKNode, accent: SKColor) {
        // 左右可拍動龍翼（以肩膀為軸心旋轉！）
        for side in [-1.0, 1.0] {
            let wingPivot = SKNode()
            wingPivot.position = CGPoint(x: side * 42, y: 12)
            container.addChild(wingPivot)

            let wingPath = CGMutablePath()
            wingPath.move(to: .zero)
            wingPath.addQuadCurve(
                to: CGPoint(x: side * 66, y: 48),
                control: CGPoint(x: side * 32, y: 54)
            )
            wingPath.addLine(to: CGPoint(x: side * 54, y: 8))
            wingPath.addLine(to: CGPoint(x: side * 36, y: 16))
            wingPath.addLine(to: CGPoint(x: side * 24, y: -22))
            wingPath.closeSubpath()

            let wingNode = SKShapeNode(path: wingPath)
            wingNode.fillColor = accent.withAlphaComponent(0.76)
            wingNode.strokeColor = SKColor.white.withAlphaComponent(0.35)
            wingNode.lineWidth = 2.0
            wingPivot.addChild(wingNode)

            if !reduceMotion {
                let flap = SKAction.sequence([
                    .rotate(toAngle: side * 0.24, duration: 0.55),
                    .rotate(toAngle: -side * 0.14, duration: 0.55)
                ])
                wingPivot.run(.repeatForever(flap))
            }
        }

        // 六角黑曜龍軀
        let bodyHex = SKShapeNode(path: Self.makeHexagonPath(radius: 64))
        bodyHex.fillColor = skColor(hex: 0x1E293B)
        bodyHex.strokeColor = accent
        bodyHex.lineWidth = 3.0
        bodyHex.glowWidth = 3.5
        container.addChild(bodyHex)

        // 胸口龍焰核心
        let flameCore = SKShapeNode(path: Self.makeHexagonPath(radius: 24))
        flameCore.fillColor = accent.withAlphaComponent(0.85)
        flameCore.strokeColor = skColor(hex: 0xF59E0B)
        flameCore.lineWidth = 2.0
        flameCore.position = CGPoint(x: 0, y: -18)
        bodyHex.addChild(flameCore)

        let face = makeExpressiveFace(eyeSpacing: 38, angry: true, cheekColor: nil)
        face.position = CGPoint(x: 0, y: 16)
        bodyHex.addChild(face)
    }

    /// Lv.4 心魔魔王：懸浮皇冠＋菱形黑曜聖殿裝甲＋3 顆環繞運行的紫金魔晶石
    private func buildLv4DemonLordRig(into container: SKNode, accent: SKColor) {
        // 環繞運行的 3 顆魔晶浮游砲
        let orbitRing = SKNode()
        container.addChild(orbitRing)
        for i in 0..<3 {
            let angle = Double(i) * (.pi * 2.0 / 3.0)
            let crystal = SKShapeNode(rectOf: CGSize(width: 18, height: 18), cornerRadius: 4)
            crystal.fillColor = skColor(hex: 0xF59E0B)
            crystal.strokeColor = .white
            crystal.lineWidth = 1.5
            crystal.glowWidth = 4.0
            crystal.zRotation = .pi / 4
            crystal.position = CGPoint(x: cos(angle) * 86, y: sin(angle) * 86)
            orbitRing.addChild(crystal)
        }
        if !reduceMotion {
            orbitRing.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 8.0)))
        }

        // 魔王菱形主裝甲
        let armor = SKShapeNode(rectOf: CGSize(width: 112, height: 112), cornerRadius: 24)
        armor.fillColor = skColor(hex: 0x162032)
        armor.strokeColor = accent
        armor.lineWidth = 3.5
        armor.glowWidth = 5.0
        armor.zRotation = .pi / 4
        container.addChild(armor)

        // 懸浮紫金皇冠
        let crownPath = CGMutablePath()
        crownPath.move(to: CGPoint(x: -26, y: 0))
        crownPath.addLine(to: CGPoint(x: -20, y: 22))
        crownPath.addLine(to: CGPoint(x: -8, y: 8))
        crownPath.addLine(to: CGPoint(x: 0, y: 26))
        crownPath.addLine(to: CGPoint(x: 8, y: 8))
        crownPath.addLine(to: CGPoint(x: 20, y: 22))
        crownPath.addLine(to: CGPoint(x: 26, y: 0))
        crownPath.closeSubpath()

        let crown = SKShapeNode(path: crownPath)
        crown.fillColor = skColor(hex: 0xF59E0B)
        crown.strokeColor = .white
        crown.lineWidth = 1.5
        crown.glowWidth = 3.0
        crown.position = CGPoint(x: 0, y: 68)
        container.addChild(crown)

        let face = makeExpressiveFace(eyeSpacing: 42, angry: true, cheekColor: accent)
        face.position = CGPoint(x: 0, y: 4)
        container.addChild(face)
    }

    private func makeExpressiveFace(eyeSpacing: CGFloat, angry: Bool, cheekColor: SKColor?) -> SKNode {
        let face = SKNode()
        let leftEye = SKShapeNode(rectOf: CGSize(width: 14, height: angry ? 9 : 16), cornerRadius: 5)
        leftEye.fillColor = skColor(hex: 0xF6F3EC)
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -eyeSpacing / 2, y: 8)
        leftEye.zRotation = angry ? -0.22 : 0
        face.addChild(leftEye)

        let rightEye = SKShapeNode(rectOf: CGSize(width: 14, height: angry ? 9 : 16), cornerRadius: 5)
        rightEye.fillColor = skColor(hex: 0xF6F3EC)
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: eyeSpacing / 2, y: 8)
        rightEye.zRotation = angry ? 0.22 : 0
        face.addChild(rightEye)

        if let cheekColor {
            for side in [-1.0, 1.0] {
                let cheek = SKShapeNode(rectOf: CGSize(width: 16, height: 6), cornerRadius: 3)
                cheek.fillColor = cheekColor.withAlphaComponent(0.55)
                cheek.strokeColor = .clear
                cheek.position = CGPoint(x: CGFloat(side) * (eyeSpacing / 2 + 6), y: -6)
                face.addChild(cheek)
            }
        }

        // 微醺波形嘴或戰意獠牙嘴線
        let mouthPath = CGMutablePath()
        if angry {
            mouthPath.move(to: CGPoint(x: -14, y: -12))
            mouthPath.addLine(to: CGPoint(x: -7, y: -7))
            mouthPath.addLine(to: CGPoint(x: 0, y: -13))
            mouthPath.addLine(to: CGPoint(x: 7, y: -7))
            mouthPath.addLine(to: CGPoint(x: 14, y: -12))
        } else {
            mouthPath.move(to: CGPoint(x: -12, y: -10))
            mouthPath.addQuadCurve(to: CGPoint(x: 0, y: -10), control: CGPoint(x: -6, y: -16))
            mouthPath.addQuadCurve(to: CGPoint(x: 12, y: -10), control: CGPoint(x: 6, y: -4))
        }
        let mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = skColor(hex: 0xF6F3EC).withAlphaComponent(0.85)
        mouth.lineWidth = 2.5
        mouth.lineCap = .round
        mouth.fillColor = .clear
        face.addChild(mouth)

        // 定期眨眼動畫
        if !reduceMotion {
            let blink = SKAction.sequence([
                .wait(forDuration: 2.6, withRange: 1.2),
                .scaleY(to: 0.12, duration: 0.06),
                .scaleY(to: 1.0, duration: 0.08)
            ])
            leftEye.run(.repeatForever(blink))
            rightEye.run(.repeatForever(blink))
        }
        return face
    }

    private func updateMonsterCriticalAura(isCritical: Bool) {
        guard let glow = monsterRootNode.childNode(withName: "backGlow") as? SKSpriteNode else { return }
        glow.removeAction(forKey: "criticalPulse")
        if isCritical && !reduceMotion {
            glow.color = skColor(hex: 0xF43F5E)
            let fastPulse = SKAction.sequence([
                .fadeAlpha(to: 0.48, duration: 0.35),
                .fadeAlpha(to: 0.15, duration: 0.35)
            ])
            glow.run(.repeatForever(fastPulse), withKey: "criticalPulse")
        } else {
            glow.color = skColor(hex: currentSpec.accentHex)
            glow.alpha = 0.28
        }
    }

    // MARK: - Combat VFX Helpers

    private func spawnSwordSlashArc() {
        let slashPath = CGMutablePath()
        slashPath.move(to: CGPoint(x: -88, y: -54))
        slashPath.addQuadCurve(
            to: CGPoint(x: 92, y: 68),
            control: CGPoint(x: -12, y: 38)
        )
        slashPath.addQuadCurve(
            to: CGPoint(x: -88, y: -54),
            control: CGPoint(x: 16, y: -12)
        )
        let slash = SKShapeNode(path: slashPath)
        slash.fillColor = .white
        slash.strokeColor = skColor(hex: 0x2DD4BF)
        slash.lineWidth = 3.0
        slash.glowWidth = 8.0
        slash.position = CGPoint(x: 0, y: 12)
        slash.setScale(0.55)
        vfxOverlayNode.addChild(slash)

        slash.run(.sequence([
            .group([
                .scale(to: 1.18, duration: 0.12),
                .fadeOut(withDuration: 0.16)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnHitSparks(color: SKColor, count: Int) {
        let burst = SKEmitterNode()
        burst.particleTexture = Self.sparkDiamondTexture
        burst.particleBirthRate = CGFloat(count) * 14
        burst.numParticlesToEmit = count
        burst.particleLifetime = 0.55
        burst.particleLifetimeRange = 0.20
        burst.position = CGPoint(x: 0, y: 12)
        burst.emissionAngleRange = .pi * 2
        burst.particleSpeed = 165
        burst.particleSpeedRange = 75
        burst.yAcceleration = -220
        burst.particleAlpha = 1.0
        burst.particleAlphaSpeed = -1.6
        burst.particleScale = 0.38
        burst.particleScaleRange = 0.18
        burst.particleScaleSpeed = -0.45
        burst.particleColor = color
        burst.particleColorBlendFactor = 1.0
        burst.particleBlendMode = .add
        vfxOverlayNode.addChild(burst)

        burst.run(.sequence([
            .wait(forDuration: 0.8),
            .removeFromParent()
        ]))
    }

    private func spawnFloatingCombatText(_ text: String, color: SKColor, fontSize: CGFloat, startOffset: CGPoint) {
        let label = SKLabelNode(text: text)
        label.fontName = "PingFangTC-Semibold"
        label.fontSize = fontSize
        label.fontColor = color
        label.position = startOffset
        label.setScale(0.6)
        vfxOverlayNode.addChild(label)

        label.run(.sequence([
            .group([
                .scale(to: 1.08, duration: 0.12),
                .moveBy(x: 0, y: 24, duration: 0.18)
            ]),
            .scale(to: 1.0, duration: 0.08),
            .group([
                .moveBy(x: 0, y: 22, duration: 0.45),
                .fadeOut(withDuration: 0.45)
            ]),
            .removeFromParent()
        ]))
    }

    private func runCameraShake(intensity: CGFloat, duration: TimeInterval) {
        let steps = 6
        let stepTime = duration / Double(steps)
        var actions: [SKAction] = []
        for i in 0..<steps {
            let damping = 1.0 - (CGFloat(i) / CGFloat(steps))
            let dx = (i.isMultiple(of: 2) ? 1 : -1) * intensity * damping
            let dy = (i.isMultiple(of: 3) ? 1 : -1) * (intensity * 0.6) * damping
            actions.append(.move(to: CGPoint(x: dx, y: dy), duration: stepTime))
        }
        actions.append(.move(to: .zero, duration: stepTime))
        worldNode.run(.sequence(actions), withKey: "cameraShake")
    }

    // MARK: - Pure CoreGraphics Texture & Path Generators

    private func skColor(hex: UInt32, alpha: CGFloat = 1.0) -> SKColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return SKColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func makeHexagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3.0) - (.pi / 2.0)
            let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func makeRadialParticleTexture(size: Int, hardEdge: Bool) -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }
        let center = CGPoint(x: CGFloat(size) / 2.0, y: CGFloat(size) / 2.0)
        let radius = CGFloat(size) / 2.0
        if hardEdge {
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
        } else if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(red: 1, green: 1, blue: 1, alpha: 1.0),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.35),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 0.55, 1.0]
        ) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }

    private static func makeDiamondParticleTexture(size: Int) -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }
        let mid = CGFloat(size) / 2.0
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: mid, y: CGFloat(size - 2)))
        ctx.addLine(to: CGPoint(x: CGFloat(size - 2), y: mid))
        ctx.addLine(to: CGPoint(x: mid, y: 2))
        ctx.addLine(to: CGPoint(x: 2, y: mid))
        ctx.closePath()
        ctx.fillPath()
        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: cgImage)
    }
}
