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
                        progressLine
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
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

    // MARK: - Daily check-in

    private var topStatusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                let day = CombatEngine.effectiveToday(for: progress)
                HStack(spacing: 6) {
                    Text(day, format: .dateTime.month().day())
                    if progress.demoRapidMode && !progress.pureRecordingMode {
                        Text("・演練日")
                    }
                }
                .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ThemeTokens.inkSecondary)
                Spacer()
                Button(action: toggleGoalMode) {
                    Label(progress.goalMode == .strictAbstinence ? "完全斷酒" : "減量 \(weeklyUsed)/\(progress.weeklySessionLimit)",
                          systemImage: "arrow.left.arrow.right")
                        .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .semibold))
                        .monospacedDigit()
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("切換目標模式")
                .accessibilityValue(progress.goalMode.displayName)
                .accessibilityHint("切換完全斷酒或減量控酒模式")
                if !progress.pureRecordingMode {
                    Button(action: onOpenDemo) {
                        Label("開啟 MAIC Demo 控制台", systemImage: "slider.horizontal.3")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(isVictoryStandby ? "你的戒酒紀錄" : "今天喝酒了嗎？")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(ThemeTokens.inkPrimary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isHeader)
                .accessibilityAction(named: "開啟 Demo 控制台", onOpenDemo)
                .onLongPressGesture(minimumDuration: 0.6, perform: onOpenDemo)
        }
        .foregroundStyle(ThemeTokens.inkPrimary)
    }

    private var monsterBattleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("第 \(activeMonster.level) 關")
                    .font(ThemeTokens.roundedTitleFont(.caption, weight: .bold))
                    .monospacedDigit()
                Spacer()
                Text(activeMonster.name)
                    .font(.subheadline.weight(.semibold))
            }
            Divider().overlay(ThemeTokens.receiptInk.opacity(0.45))
            Text(activeMonster.situation)
                .font(.system(.title, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(activeMonster.subtitle)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            MonsterAvatarView(
                spec: activeMonster,
                hpRatio: hpRatio,
                isStageVisible: isStageVisible && !showDrinkSheet && celebrationContext == nil,
                hitTrigger: hitTrigger, shieldTrigger: shieldTrigger,
                lastDamageAmount: lastDamageAmount, lastHealAmount: lastHealAmount,
                lastHealWasWithinBudget: lastHealWasWithinBudget
            )

            HStack(alignment: .firstTextBaseline) {
                Text("怪獸體力")
                Spacer()
                Text("\(progress.currentMonsterHP) / \(activeMonster.maxHP) HP")
                    .monospacedDigit()
            }
            .font(ThemeTokens.roundedTitleFont(.caption, weight: .semibold))
            .accessibilityElement(children: .combine)
            ProgressView(value: hpRatio)
                .tint(ThemeTokens.printGreen)
                .environment(\.colorScheme, .light)
                .accessibilityHidden(true)
            if let feedbackNotice {
                Text(feedbackNotice.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ThemeTokens.printGreen)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(ThemeTokens.receiptInk)
        .padding(18)
        .background(ThemeTokens.receiptPaper, in: .rect(cornerRadius: 4))
    }

    private var victoryStandbyStage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("四關完成", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(ThemeTokens.printGreen)
            Text("破曉勇者")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Divider()
            Text("已累積 \(progress.totalCleanCheckIns) 次沒喝酒的紀錄，估計省下 NT$ \(CombatEngine.impactSummary(for: progress).totalSavedNTD)。")
                .monospacedDigit()
            Button(action: onOpenCampaign) {
                Label("前往關卡・選擇再戰怪獸", systemImage: "arrow.forward")
            }
            .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.printGreen,
                                                 foregroundColor: ThemeTokens.receiptPaper))
        }
        .foregroundStyle(ThemeTokens.receiptInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ThemeTokens.receiptPaper, in: .rect(cornerRadius: 4))
    }

    private var actionDock: some View {
        VStack(spacing: 4) {
            Button(action: performSoberAttack) {
                HStack {
                    Label("今日沒喝", systemImage: "waterbottle")
                    Spacer(minLength: 8)
                    Text("攻擊 \(attackPreview) HP")
                        .font(ThemeTokens.roundedTitleFont(.subheadline))
                        .monospacedDigit()
                }
            }
            .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.receiptPaper,
                                                 foregroundColor: ThemeTokens.receiptInk))
            Button { showDrinkSheet = true } label: {
                HStack {
                    Label("今天有喝", systemImage: "pencil.line")
                    Spacer(minLength: 8)
                    Text("記下杯數與情境")
                        .font(.subheadline)
                    Image(systemName: "chevron.right").font(.caption)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(ThemeTokens.inkPrimary)
            .padding(.horizontal, 12)
            .accessibilityIdentifier("battle.logDrink")
        }
    }

    private var progressLine: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
            : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(ThemeTokens.cardStroke)
            layout {
                Text("清醒連勝 \(progress.currentStreak) 天")
                Text("護盾 \(progress.honestShieldCount) 次")
                Text("覺察 \(progress.insightXP) XP")
            }
            .font(ThemeTokens.roundedTitleFont(.caption, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(ThemeTokens.inkSecondary)
        }
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
        showNotice("目標已改為\(progress.goalMode.displayName)")
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
            showNotice("造成 \(abs(summary.hpDelta)) HP 傷害")
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
            showNotice("今天已經打過卡了，明天可以再記一筆。")
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
                showNotice("已記下飲酒情境。護盾生效，怪獸回復 \(summary.hpDelta) HP。")
            } else {
                showNotice("已記下這次飲酒，連勝保留。怪獸回復 \(summary.hpDelta) HP。")
            }
        case .alreadyCheckedInToday:
            showNotice("今天已經打過卡了，明天可以再記一筆。")
        case .campaignStandbyRequiresRematch:
            onOpenCampaign()
        case .requiresTrigger:
            break // 表單保留輸入，提示玩家補選情境。
        }
        return status
    }

    private func showNotice(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            feedbackNotice = BattleFloatingNotice(text: text)
        }
    }
}

private struct BattleFloatingNotice: Equatable {
    let id = UUID()
    let text: String
}

private struct LevelUpContext: Identifiable {
    var id: Int { defeated.level }
    let defeated: MonsterSpec
    let promotedTo: MonsterSpec?
    let completedCampaign: Bool
}
