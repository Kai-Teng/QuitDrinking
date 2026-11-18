import Accessibility
import SwiftUI
import SwiftData

/// 分頁一：主戰場與晉級互動舞台。
struct BattleArenaView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let progress: PlayerProgress
    let records: [CheckInRecord]
    let isStageVisible: Bool
    let onOpenDemo: () -> Void
    let onOpenCampaign: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDrinkSheet = false
    @State private var saveFailed = false
    @State private var hitTrigger = 0
    @State private var shieldTrigger = 0
    @State private var lastDamageAmount = 100
    @State private var lastHealAmount = 45
    @State private var lastHealWasWithinBudget = false
    @State private var feedbackNotice: BattleFloatingNotice?
    @State private var celebrationContext: LevelUpContext?

    private var activeMonster: MonsterSpec {
        MonsterCatalog.spec(forLevel: progress.activeMonsterLevel)
    }

    private var weeklyUsed: Int {
        CombatEngine.currentWeeklyDrinksUsed(progress: progress, records: records)
    }

    private var attackPreview: Int {
        CombatEngine.previewAttackDamage(for: progress)
    }

    private var hpRatio: Double {
        guard activeMonster.maxHP > 0 else { return 0 }
        return max(0, min(1, Double(progress.currentMonsterHP) / Double(activeMonster.maxHP)))
    }

    private var hpBarColor: Color {
        if hpRatio > 0.40 { return ThemeTokens.mintVitality }
        if hpRatio > 0.20 { return ThemeTokens.amberShield }
        return ThemeTokens.coralAlert
    }

    private var isVictoryStandby: Bool {
        CombatEngine.isCampaignVictoryStandby(progress)
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 16) {
                    topStatusBar
                    if isVictoryStandby {
                        victoryStandbyStage
                    } else {
                        monsterBattleCard
                        actionDock
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(ThemeTokens.canvasBackground)
        .fullScreenCover(item: $celebrationContext) { victory in
            LevelUpCelebrationView(
                defeatedMonster: victory.defeated,
                nextMonster: victory.promotedTo,
                completedCampaign: victory.completedCampaign
            ) {
                celebrationContext = nil
            }
        }
        .alert("未能儲存變更", isPresented: $saveFailed) {
            Button("好", role: .cancel) {}
        } message: {
            Text("請再試一次。")
        }
        .task(id: feedbackNotice?.id) {
            guard feedbackNotice != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2.4))
            } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { feedbackNotice = nil }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: hitTrigger)
        .sensoryFeedback(.warning, trigger: shieldTrigger)
        .sheet(isPresented: $showDrinkSheet) {
            let used = CombatEngine.nextCheckInWeeklyDrinksUsed(progress: progress, records: records)
            HonestShieldSheet(
                monsterSpec: activeMonster,
                willTriggerShield: CombatEngine.requiresHonestShield(progress: progress, weeklyUsed: used),
                currentHP: progress.currentMonsterHP,
                weeklyUsed: used,
                weeklyLimit: progress.weeklySessionLimit,
                isModerationMode: progress.goalMode == .moderationBudget
            ) { units, triggers, note in
                try handleDrinkSubmission(units: units, triggers: triggers, note: note)
            }
        }
    }

    // MARK: - Top Bar

    private var topStatusBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("戰場")
                    .font(ThemeTokens.roundedTitleFont(.title3, weight: .bold))
                    .foregroundStyle(ThemeTokens.inkPrimary)

                if !progress.pureRecordingMode {
                    Text(progress.demoRapidMode ? "模擬日 Day \(progress.virtualDayOffset + 1)" : "嚴格每日一次模式")
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "開啟 Demo 控制台", onOpenDemo)
            .onLongPressGesture(minimumDuration: 0.6) {
                onOpenDemo()
            }

            Spacer()

            Button {
                toggleGoalMode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: progress.goalMode == .strictAbstinence ? "flame.fill" : "gauge.with.dots.needle.33percent")
                        .font(.caption.weight(.semibold))
                    if progress.goalMode == .strictAbstinence {
                        Text("完全斷酒")
                    } else {
                        Text("減量 \(weeklyUsed)/\(progress.weeklySessionLimit)")
                            .monospacedDigit()
                    }
                }
                .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                .foregroundStyle(progress.goalMode == .strictAbstinence ? ThemeTokens.mintVitality : ThemeTokens.skyModeration)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(ThemeTokens.cardSurface)
                        .overlay(Capsule().strokeBorder(ThemeTokens.cardStroke, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("切換目標模式")
            .accessibilityValue(progress.goalMode.displayName)
            .accessibilityHint("切換完全斷酒或減量控酒模式")

            if !progress.pureRecordingMode {
                Button(action: onOpenDemo) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ThemeTokens.inkPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(ThemeTokens.cardSurface)
                                .overlay(Circle().strokeBorder(ThemeTokens.cardStroke, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("開啟 MAIC Demo 控制台")
            }
        }
    }

    // MARK: - Battle Stage

    private var monsterBattleCard: some View {
        VStack(spacing: 16) {
            // Monster header + HP bar
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Lv.\(activeMonster.level)")
                        .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                        .foregroundStyle(ThemeTokens.canvasBackground)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: activeMonster.accentHex)))

                    Text(activeMonster.name)
                        .font(ThemeTokens.roundedTitleFont(.title2, weight: .bold))
                        .foregroundStyle(ThemeTokens.inkPrimary)

                    Spacer()

                    Text("建議 \(activeMonster.suggestedDays) 天")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.inkSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ThemeTokens.canvasBackground.opacity(0.75))
                        Capsule()
                            .fill(hpBarColor)
                            .frame(width: geo.size.width * hpRatio)
                            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8), value: hpRatio)
                    }
                }
                .frame(height: 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("怪獸血條")
                .accessibilityValue("\(progress.currentMonsterHP) 除以 \(activeMonster.maxHP)")

                HStack {
                    Text("HP \(progress.currentMonsterHP) / \(activeMonster.maxHP)")
                        .font(ThemeTokens.roundedTitleFont(.subheadline))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.inkPrimary)

                    Spacer()

                    if let feedbackNotice {
                        Text(feedbackNotice.text)
                            .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                            .foregroundStyle(feedbackNotice.color)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        Text(activeMonster.subtitle)
                            .font(.caption)
                            .foregroundStyle(ThemeTokens.inkSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            MonsterAvatarView(
                spec: activeMonster,
                hpRatio: hpRatio,
                isStageVisible: isStageVisible && !showDrinkSheet && celebrationContext == nil,
                hitTrigger: hitTrigger,
                shieldTrigger: shieldTrigger,
                lastDamageAmount: lastDamageAmount,
                lastHealAmount: lastHealAmount,
                lastHealWasWithinBudget: lastHealWasWithinBudget
            )

            Spacer(minLength: 0)

            // RPG Status Pills
            let statsLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(spacing: 8))
            statsLayout {
                statPill(
                    icon: "bolt.fill",
                    tint: ThemeTokens.mintVitality,
                    text: "連勝 \(progress.currentStreak) 天"
                )
                statPill(
                    icon: "shield.lefthalf.filled",
                    tint: ThemeTokens.amberShield,
                    text: "誠實護盾 \(progress.honestShieldCount) 次"
                )
                statPill(
                    icon: "sparkles",
                    tint: ThemeTokens.skyModeration,
                    text: "反省 \(progress.insightXP) XP"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private var victoryStandbyStage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(ThemeTokens.amberShield)

            Text("破曉勇者・主線全破")
                .font(ThemeTokens.roundedTitleFont(.title, weight: .bold))
                .foregroundStyle(ThemeTokens.inkPrimary)

            Text("你已擊敗所有階段心魔！終身累計省下 NT$ \(CombatEngine.impactSummary(for: progress).totalSavedNTD)，可從關卡地圖挑選任一怪獸再次挑戰。")
                .font(.subheadline)
                .foregroundStyle(ThemeTokens.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                onOpenCampaign()
            } label: {
                Label("前往關卡・選擇再戰怪獸", systemImage: "map.fill")
            }
            .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.amberShield))
            .padding(.top, 8)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                .fill(ThemeTokens.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeTokens.cardRadius, style: .continuous)
                        .strokeBorder(ThemeTokens.amberShield.opacity(0.35), lineWidth: 1.5)
                )
        )
    }

    private var actionDock: some View {
        let shieldNow = CombatEngine.willTriggerHonestShieldOnDrink(progress: progress, records: records)
        return VStack(spacing: 10) {
            Button {
                performSoberAttack()
            } label: {
                Label("今日沒喝・發動攻擊 (-\(attackPreview))", systemImage: "bolt.fill")
                    .monospacedDigit()
            }
            .buttonStyle(TactilePrimaryButtonStyle())

            Button {
                showDrinkSheet = true
            } label: {
                Label(
                    shieldNow ? "今天有喝・開啟誠實護盾" : "今天有喝・理性小酌紀錄",
                    systemImage: "shield.lefthalf.filled"
                )
            }
            .buttonStyle(
                TactileOutlineButtonStyle(
                    accentColor: shieldNow ? ThemeTokens.amberShield : ThemeTokens.skyModeration
                )
            )
        }
    }

    private func statPill(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(ThemeTokens.roundedTitleFont(.caption2, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(ThemeTokens.inkPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(ThemeTokens.canvasBackground.opacity(0.65)))
    }

    // MARK: - Actions

    private func toggleGoalMode() {
        progress.goalMode = progress.goalMode == .strictAbstinence ? .moderationBudget : .strictAbstinence
        do {
            try CombatEngine.saveAndSync(progress: progress, records: records, context: modelContext)
        } catch {
            saveFailed = true
            return
        }
        showNotice(
            "已切換為「\(progress.goalMode.displayName)」",
            color: progress.goalMode == .strictAbstinence ? ThemeTokens.mintVitality : ThemeTokens.skyModeration
        )
    }

    private func performSoberAttack() {
        let status: CombatActionStatus
        do {
            status = try CombatEngine.checkIn(.soberAttack, progress: progress, context: modelContext)
        } catch {
            saveFailed = true
            return
        }

        switch status {
        case .applied(let summary):
            lastDamageAmount = abs(summary.hpDelta)
            hitTrigger += 1
            showNotice("造成 \(abs(summary.hpDelta)) HP 傷害", color: ThemeTokens.mintVitality)
            if let defeated = summary.defeatedMonster {
                celebrationContext = LevelUpContext(
                    defeated: defeated,
                    promotedTo: summary.promotedToMonster,
                    completedCampaign: summary.completedCampaign
                )
            }
        case .requiresTrigger:
            assertionFailure("清醒攻擊不需要情境標籤")
        case .alreadyCheckedInToday:
            showNotice("今日已完成戰役紀錄，明天再來發動攻擊！", color: ThemeTokens.amberShield)
        case .campaignStandbyRequiresRematch:
            onOpenCampaign()
        }
    }

    private func handleDrinkSubmission(units: Int, triggers: [RelapseTriggerTag], note: String) throws -> CombatActionStatus {
        let status = try CombatEngine.checkIn(
            .drink(units: units, triggers: triggers, note: note), progress: progress, context: modelContext
        )
        switch status {
        case .applied(let summary):
            lastHealAmount = summary.hpDelta
            lastHealWasWithinBudget = (summary.outcome == .withinBudgetDrink)
            shieldTrigger += 1
            if summary.outcome == .honestShieldRelapse {
                showNotice("誠實護盾展開！怪獸僅回 +\(summary.hpDelta) HP", color: ThemeTokens.amberShield)
            } else {
                showNotice("額度內理性小酌（+\(summary.hpDelta) HP，連勝保留）", color: ThemeTokens.skyModeration)
            }
        case .alreadyCheckedInToday:
            showNotice("今日已完成戰役紀錄，明天再來紀錄！", color: ThemeTokens.amberShield)
        case .campaignStandbyRequiresRematch:
            onOpenCampaign()
        case .requiresTrigger:
            break // 表單保留輸入，提示玩家補選情境。
        }
        return status
    }

    private func showNotice(_ text: String, color: Color) {
        AccessibilityNotification.Announcement(text).post()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            feedbackNotice = BattleFloatingNotice(text: text, color: color)
        }
    }
}

private struct BattleFloatingNotice: Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

private struct LevelUpContext: Identifiable {
    var id: Int { defeated.level }
    let defeated: MonsterSpec
    let promotedTo: MonsterSpec?
    let completedCampaign: Bool
}
