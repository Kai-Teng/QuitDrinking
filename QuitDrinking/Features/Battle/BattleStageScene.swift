import SpriteKit
import SwiftUI
import CoreGraphics

/// 桌邊的戒酒戰鬥場景：酒瓶、水杯與杯墊為固定版畫，只有怪獸和操作回饋會動。
@MainActor
final class BattleStageScene: SKScene {
    // MARK: - State
    private var currentSpec: MonsterSpec = MonsterCatalog.spec(forLevel: 1)
    private var currentHPRatio: Double = 1.0
    private var reduceMotion: Bool = false

    // MARK: - Scene Graph Nodes
    private let worldNode = SKNode()
    private let tabletop = SKNode()
    private let monsterRootNode = SKNode()
    private let vfxOverlayNode = SKNode()

    private var needsStaticFrame = true
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
        needsStaticFrame = true
    }

    // MARK: - Public Configuration & Triggers

    func configure(spec: MonsterSpec, hpRatio: Double, reduceMotion: Bool) {
        let levelChanged = spec.level != currentSpec.level
        let motionChanged = self.reduceMotion != reduceMotion
        let prevCritical = currentHPRatio <= 0.30 && currentHPRatio > 0
        let nowCritical = hpRatio <= 0.30 && hpRatio > 0

        currentSpec = spec
        currentHPRatio = hpRatio
        self.reduceMotion = reduceMotion

        needsStaticFrame = true
        guard isSceneBuilt else {
            buildSceneIfNeeded()
            return
        }

        if motionChanged {
            worldNode.removeAllActions()
            worldNode.position = .zero
            vfxOverlayNode.removeAllChildren()
        }
        if levelChanged || motionChanged {
            rebuildMonsterRig(animateEntrance: levelChanged)
        } else if prevCritical != nowCritical {
            updateWoundedAppearance(isCritical: nowCritical)
        }
    }

    /// With Reduce Motion the scene is static between configuration and layout changes.
    func shouldRenderFrame() -> Bool {
        guard reduceMotion else { return true }
        defer { needsStaticFrame = false }
        return needsStaticFrame
    }

    func triggerAttackVFX(damage: Int) {
        guard !reduceMotion else { return }
        buildSceneIfNeeded()

        // 1. 對角刀光斬擊弧線
        spawnSwordSlashArc()

        // 2. 粒子爆發火花
        spawnHitSparks(color: SKColor(ThemeTokens.printGreen), count: 32)

        // 3. 怪獸受擊後退、閃白與鏡頭震動
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

        // 受擊衝擊光圈
        let shockRing = SKShapeNode(circleOfRadius: 28)
        shockRing.strokeColor = SKColor(ThemeTokens.printGreen)
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
            color: SKColor(ThemeTokens.printGreen),
            fontSize: damage >= 130 ? 24 : 21,
            startOffset: CGPoint(x: 0, y: 58)
        )
    }

    func triggerShieldVFX(healAmount: Int, isWithinBudget: Bool) {
        guard !reduceMotion else { return }
        buildSceneIfNeeded()

        let tint = SKColor(ThemeTokens.printGreen)

        // 1. 六角護盾能量穹頂
        let dome = SKShapeNode(path: Self.makeHexagonPath(radius: 92))
        dome.strokeColor = tint
        dome.lineWidth = 3.5
        dome.fillColor = tint.withAlphaComponent(0.16)

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
        let prefix = isWithinBudget ? "已記錄" : "誠實護盾"
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

    func pokeMonsterReaction() {
        guard !reduceMotion else { return }
        spawnHitSparks(color: SKColor(ThemeTokens.printGreen), count: 12)
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
        worldNode.addChild(tabletop)
        worldNode.addChild(monsterRootNode)
        worldNode.addChild(vfxOverlayNode)

        buildTabletop()
        rebuildMonsterRig(animateEntrance: false)
        layoutNodesForCurrentSize()
    }

    private func layoutNodesForCurrentSize() {
        worldNode.setScale(min(size.width / 338, size.height / 215, 1.1))
        monsterRootNode.position = CGPoint(x: 0, y: 8)
    }

    private func buildTabletop() {
        let ink = SKColor(ThemeTokens.receiptInk)
        let paper = SKColor(ThemeTokens.receiptPaper)
        let wash = SKColor(ThemeTokens.printGreen)
        // These still-life outlines use a fixed print coordinate system. Only layout scales the group.
        func line(_ points: [CGPoint], width: CGFloat = 1.4, opacity: CGFloat = 1) {
            guard let first = points.first else { return }
            let path = CGMutablePath()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            let stroke = SKShapeNode(path: path)
            stroke.strokeColor = ink.withAlphaComponent(opacity)
            stroke.lineWidth = width
            stroke.lineCap = .round
            tabletop.addChild(stroke)
        }

        line([.init(x: -160, y: -45), .init(x: 160, y: -45)], width: 1, opacity: 0.28)
        line([.init(x: -134, y: -76), .init(x: -77, y: -76)], width: 1, opacity: 0.18)
        line([.init(x: 65, y: -84), .init(x: 143, y: -84)], width: 1, opacity: 0.18)

        let coaster = SKShapeNode(ellipseOf: .init(width: 158, height: 36))
        coaster.position = .init(x: 0, y: -58)
        coaster.fillColor = wash.withAlphaComponent(0.20)
        coaster.strokeColor = ink
        coaster.lineWidth = 1.8
        tabletop.addChild(coaster)
        let inner = SKShapeNode(ellipseOf: .init(width: 143, height: 27))
        inner.strokeColor = ink.withAlphaComponent(0.5)
        inner.lineWidth = 1
        coaster.addChild(inner)

        // An empty, capped beer bottle stands behind the coaster.
        let bottle = CGMutablePath()
        bottle.move(to: .init(x: -135, y: 66))
        bottle.addLine(to: .init(x: -119, y: 66))
        bottle.addLine(to: .init(x: -117, y: 37))
        bottle.addQuadCurve(to: .init(x: -106, y: 13), control: .init(x: -107, y: 25))
        bottle.addLine(to: .init(x: -103, y: -44))
        bottle.addQuadCurve(to: .init(x: -109, y: -51), control: .init(x: -103, y: -51))
        bottle.addLine(to: .init(x: -142, y: -53))
        bottle.addQuadCurve(to: .init(x: -149, y: -45), control: .init(x: -150, y: -52))
        bottle.addLine(to: .init(x: -151, y: 14))
        bottle.addQuadCurve(to: .init(x: -139, y: 37), control: .init(x: -151, y: 23))
        bottle.closeSubpath()
        let glass = SKShapeNode(path: bottle)
        glass.fillColor = wash
        glass.strokeColor = ink
        glass.lineWidth = 2
        tabletop.addChild(glass)
        let cap = SKShapeNode(rectOf: .init(width: 22, height: 7), cornerRadius: 1)
        cap.position = .init(x: -127, y: 67)
        cap.fillColor = ink
        cap.strokeColor = ink
        tabletop.addChild(cap)
        let wrapper = SKShapeNode(rectOf: .init(width: 41, height: 32), cornerRadius: 1)
        wrapper.fillColor = paper
        wrapper.strokeColor = ink
        wrapper.zRotation = 0.035
        wrapper.position = .init(x: -127, y: -16)
        tabletop.addChild(wrapper)
        let print = SKLabelNode(text: "啤酒")
        print.fontName = "PingFangTC-Medium"
        print.fontColor = ink
        print.fontSize = 13
        print.verticalAlignmentMode = .center
        wrapper.addChild(print)

        // A fluted water tumbler in the foreground.
        let tumbler = CGMutablePath()
        tumbler.move(to: .init(x: 94, y: -1))
        tumbler.addQuadCurve(to: .init(x: 143, y: -1), control: .init(x: 116, y: 6))
        tumbler.addLine(to: .init(x: 137, y: -56))
        tumbler.addQuadCurve(to: .init(x: 102, y: -56), control: .init(x: 119, y: -64))
        tumbler.closeSubpath()
        let cup = SKShapeNode(path: tumbler)
        cup.strokeColor = ink
        cup.fillColor = paper
        cup.lineWidth = 2
        tabletop.addChild(cup)
        let water = CGMutablePath()
        water.move(to: .init(x: 98, y: -24))
        water.addQuadCurve(to: .init(x: 139, y: -23), control: .init(x: 118, y: -17))
        water.addLine(to: .init(x: 135, y: -54))
        water.addQuadCurve(to: .init(x: 104, y: -54), control: .init(x: 119, y: -59))
        water.closeSubpath()
        let waterFill = SKShapeNode(path: water)
        waterFill.fillColor = wash.withAlphaComponent(0.29)
        waterFill.strokeColor = .clear
        tabletop.addChild(waterFill)
        for x in [104, 111, 128, 135] {
            line([.init(x: x, y: -13), .init(x: (x - 119) * 4 / 5 + 119, y: -50)],
                 width: 1, opacity: 0.52)
        }
        line([.init(x: 95, y: -2), .init(x: 117, y: -5), .init(x: 141, y: -2)],
             width: 1.4, opacity: 0.75)
    }

    // MARK: - Monster rigs

    private func rebuildMonsterRig(animateEntrance: Bool) {
        monsterRootNode.removeAllActions()
        monsterRootNode.removeAllChildren()
        monsterRootNode.position = CGPoint(x: 0, y: 8)
        monsterRootNode.zRotation = 0

        let accent = currentSpec.level == 1 ? SKColor(ThemeTokens.amberShield) : SKColor(ThemeTokens.printGreen)

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
                .moveBy(x: 0, y: 3, duration: 1.35),
                .moveBy(x: 0, y: -3, duration: 1.35)
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

        updateWoundedAppearance(isCritical: currentHPRatio <= 0.30 && currentHPRatio > 0)
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
        if !reduceMotion {
            let bubbles = SKEmitterNode()
            bubbles.particleTexture = Self.softCircleTexture
            bubbles.particleBirthRate = 5
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
        }

        // 表情五官（支援眨眼）
        let faceNode = makeExpressiveFace(eyeSpacing: 42, angry: false, cheekColor: SKColor(ThemeTokens.coralAlert))
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
        torso.fillColor = SKColor(ThemeTokens.receiptInk)
        torso.strokeColor = accent
        torso.lineWidth = 3.0

        container.addChild(torso)

        // 鎧甲胸口護紋
        let belt = SKShapeNode(rectOf: CGSize(width: 112, height: 18), cornerRadius: 6)
        belt.fillColor = SKColor(ThemeTokens.canvasBackground)
        belt.strokeColor = SKColor(ThemeTokens.amberShield)
        belt.lineWidth = 1.5
        belt.position = CGPoint(x: 0, y: -26)
        torso.addChild(belt)

        let buckle = SKShapeNode(rectOf: CGSize(width: 22, height: 22), cornerRadius: 5)
        buckle.fillColor = SKColor(ThemeTokens.amberShield)
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
        mugBody.fillColor = SKColor(ThemeTokens.amberShield)
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
        buckler.fillColor = SKColor(ThemeTokens.canvasBackground)
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
        bodyHex.fillColor = SKColor(ThemeTokens.receiptInk)
        bodyHex.strokeColor = accent
        bodyHex.lineWidth = 3.0

        container.addChild(bodyHex)

        // 胸口龍焰核心
        let flameCore = SKShapeNode(path: Self.makeHexagonPath(radius: 24))
        flameCore.fillColor = accent.withAlphaComponent(0.85)
        flameCore.strokeColor = SKColor(ThemeTokens.amberShield)
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
            crystal.fillColor = SKColor(ThemeTokens.amberShield)
            crystal.strokeColor = .white
            crystal.lineWidth = 1.5

            crystal.zRotation = .pi / 4
            crystal.position = CGPoint(x: cos(angle) * 86, y: sin(angle) * 86)
            orbitRing.addChild(crystal)
        }
        if !reduceMotion {
            orbitRing.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 8.0)))
        }

        // 魔王菱形主裝甲
        let armor = SKShapeNode(rectOf: CGSize(width: 112, height: 112), cornerRadius: 24)
        armor.fillColor = SKColor(ThemeTokens.receiptInk)
        armor.strokeColor = accent
        armor.lineWidth = 3.5

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
        crown.fillColor = SKColor(ThemeTokens.amberShield)
        crown.strokeColor = .white
        crown.lineWidth = 1.5

        crown.position = CGPoint(x: 0, y: 68)
        container.addChild(crown)

        let face = makeExpressiveFace(eyeSpacing: 42, angry: true, cheekColor: accent)
        face.position = CGPoint(x: 0, y: 4)
        container.addChild(face)
    }

    private func makeExpressiveFace(eyeSpacing: CGFloat, angry: Bool, cheekColor: SKColor?) -> SKNode {
        let face = SKNode()
        let leftEye = SKShapeNode(rectOf: CGSize(width: 14, height: angry ? 9 : 16), cornerRadius: 5)
        leftEye.fillColor = SKColor(ThemeTokens.receiptPaper)
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -eyeSpacing / 2, y: 8)
        leftEye.zRotation = angry ? -0.22 : 0
        face.addChild(leftEye)

        let rightEye = SKShapeNode(rectOf: CGSize(width: 14, height: angry ? 9 : 16), cornerRadius: 5)
        rightEye.fillColor = SKColor(ThemeTokens.receiptPaper)
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
        mouth.strokeColor = SKColor(ThemeTokens.receiptPaper).withAlphaComponent(0.85)
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

    private func updateWoundedAppearance(isCritical: Bool) {
        let rig = monsterRootNode.childNode(withName: "rigContainer")
        rig?.zRotation = isCritical ? -0.09 : 0
        rig?.alpha = isCritical ? 0.78 : 1
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
        slash.strokeColor = SKColor(ThemeTokens.printGreen)
        slash.lineWidth = 3.0

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
        burst.particleBlendMode = .alpha
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
