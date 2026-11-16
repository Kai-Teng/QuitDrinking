# DawnQuest（破曉戰記）MAIC iOS 雛形實作計畫

> **For agentic workers:** Implementing natively task-by-task in this session, verifying each task with tests/builds and frequent Traditional Chinese Git commits. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the runnable native SwiftUI iOS prototype ("DawnQuest / 破曉戰記") with 3 Hero Screens, RPG combat & Honest Shield anti-churn mechanics, Swift Charts insights, WidgetKit extension, MAIC Demo controller, and a workspace project Skill.

**Architecture:** Clean 4-member modular Xcode project (`QuitDrinking.xcodeproj`) containing `QuitDrinking` (iOS 27.2 SwiftUI + SwiftData + Charts app target), `QuitDrinkingWidget` (WidgetKit extension sharing state via `SharedSnapshotStore` with safe fallback), and `QuitDrinkingTests` (XCTest unit test target). Domain combat math lives in pure value-type/MainActor-safe services separated from SwiftUI feature views.

**Tech Stack:** Swift 6.4.2, SwiftUI, SwiftData, Swift Charts, WidgetKit, XCTest, Xcode 27.2 (`iOS 27.2` SDK).

**Spec:** [2026-11-16-quitdrinking-maic-prototype-design.md](file:///Users/Kai/Xcode/QuitDrinking/docs/superpowers/specs/2026-11-16-quitdrinking-maic-prototype-design.md)

## Global Constraints

- **語言與 UI**：僅限 Swift 與 SwiftUI（禁止引入 UIKit / AppKit 視圖控制器或第三方 UI 套件）。
- **SDK 對齊**：Xcode 27.2 / `IPHONEOS_DEPLOYMENT_TARGET = 27.2`、Swift 6 並發安全；使用現代 SwiftUI API（`Tab`、`sensoryFeedback`、`PhaseAnimator`、`containerBackground`、`@Observable`）。
- **不懲罰歸零**：記錄喝酒絕對不可倒退怪獸等級，也不可歸零終身累計省錢、減碳/熱量或總擊敗數。
- **字體與無障礙**：數值採用 `.rounded` + `.monospacedDigit()`；圖示按鈕與自繪進度條具備 `accessibilityLabel`/`accessibilityValue`；動效尊重 `@Environment(\.accessibilityReduceMotion)`。
- **Git 提交**：每個可驗證里程碑完成後以繁體中文訊息提交至 Git。

## Review Focus

1. **週額度跨週與減量/斷酒切換一致性**：在 `moderationBudget` 模式下於週日跨入下週一時，本週已用次數應自動歸零重新計算；同一模擬週內從 `strictAbstinence` 切換為 `moderationBudget` 時，當週既有喝酒紀錄必須即時算入已用額度。
2. **誠實護盾回血上限與不跨級倒退**：即使玩家在極高連敗下連續輸入 `units = 10` 的酒精紀錄，單次誠實護盾回血仍嚴格鎖在 `min(units * 45, Int(Double(maxHP) * 0.20))` 且 `currentHP <= maxHP`，絕對不能退回上一隻怪獸。
3. **Lv.4 通關後圖鑑再戰不污染統計與重複計算**：擊敗 Lv.4「心魔魔王」後從 `MonsterBestiaryView` 選擇 Lv.1～Lv.4 再次挑戰時，僅重設 `activeMonsterLevel` 與 `currentMonsterHP`，`totalCleanCheckIns`、`totalMonstersDefeated`、`honestShieldCount`、`insightXP` 與 `currentStreak` 必須完整保留。
4. **Demo 模擬日推進 vs 嚴格每日鎖定邊界**：`demoRapidMode == true` 時，同一模擬日第一次打卡不推進 `virtualDayOffset`，第二次點擊才推進 `virtualDayOffset += 1`；切換為 `demoRapidMode == false` 後，若模擬當天已有紀錄，點擊打卡應回傳 `.alreadyCheckedInToday` 而不變更任何資料或偏移量。
5. **Widget App Group 未簽章時的安全降級**：當 `UserDefaults(suiteName: "group.com.quitdrinking.app")` 在個人免費簽章或測試環境不可寫入/無資料時，`SharedSnapshotStore` 必須無崩潰降級讀寫 `UserDefaults.standard` 或回傳預設範例 `BattleWidgetSnapshot`。

---

### Task 1: Xcode 專案骨架、共用設計系統與 Widget 快照儲存

**Files:**
- Create: `QuitDrinking.xcodeproj/project.pbxproj`
- Create: `QuitDrinking/App/QuitDrinkingApp.swift`
- Create: `QuitDrinking/DesignSystem/ThemeTokens.swift`
- Create: `QuitDrinking/DesignSystem/TactileButtonStyles.swift`
- Create: `QuitDrinking/Domain/SharedSnapshotStore.swift`
- Create: `QuitDrinkingTests/SharedSnapshotStoreTests.swift`

**Interfaces:**
- Produces: `ThemeTokens` (colors `#0D131F`, `#162032`, `#F6F3EC`, `#94A3B8`, `#2DD4BF`, `#F59E0B`, `#F43F5E`, `#38BDF8`, font helpers), `TactilePrimaryButtonStyle`, `TactileOutlineButtonStyle`, `BattleWidgetSnapshot` (`Codable`, `Sendable`), `SharedSnapshotStore` (`save(_:defaults:)`, `load(defaults:) -> BattleWidgetSnapshot`).

- [ ] **Step 1: 建立 `QuitDrinking/DesignSystem/ThemeTokens.swift` 與 `TactileButtonStyles.swift` 與 `SharedSnapshotStore.swift`**
  - Define semantic color tokens matching "Twilight Tavern to Crisp Dawn" (`canvasBackground`, `cardSurface`, `inkPrimary`, `inkSecondary`, `mintVitality`, `amberShield`, `coralAlert`, `skyModeration`), `roundedNumericFont(size:weight:)`, and tactile button styles (`<= 200ms` spring scale feedback).
  - Define `BattleWidgetSnapshot: Codable, Sendable, Equatable` and `SharedSnapshotStore` supporting injected `UserDefaults` (for unit testing & App Group fallback to `.standard`) + static `.placeholder`.
- [ ] **Step 2: 建立最小可編譯 App 入口與 Widget 佔位、測試目標與 `QuitDrinking.xcodeproj/project.pbxproj`**
  - Include 3 targets: `QuitDrinking` (App), `QuitDrinkingWidget` (App Extension, embedded in `QuitDrinking`), `QuitDrinkingTests` (Unit Test Bundle, `TEST_HOST` = `QuitDrinking`).
  - Configure `IPHONEOS_DEPLOYMENT_TARGET = 27.2`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete` (or targeted), `GENERATE_INFOPLIST_FILE = YES` where clean + minimal Widget `Info.plist`.
- [ ] **Step 3: 撰寫 `SharedSnapshotStoreTests.swift` 驗證快照讀寫與無資料安全降級**
  - Test `testSaveAndLoadRoundTrip` and `testLoadEmptyDefaultsReturnsPlaceholder`.
- [ ] **Step 4: 執行 `xcodebuild test`（iOS Simulator）驗證專案編譯與 Task 1 測試通過**
  - Expected: `TEST SUCCEEDED` for `SharedSnapshotStoreTests`.
- [ ] **Step 5: Git 提交 Task 1**
  - `git add ... && git commit -m "建立 DawnQuest Xcode 專案架構、設計系統 Token 與 Widget 快照儲存"`

---

### Task 2: Domain 資料模型、怪獸圖鑑與 RPG 戰鬥引擎（TDD）

**Files:**
- Create: `QuitDrinking/Domain/Models.swift`
- Create: `QuitDrinking/Domain/MonsterCatalog.swift`
- Create: `QuitDrinking/Domain/CombatEngine.swift`
- Create: `QuitDrinkingTests/CombatEngineTests.swift`

**Interfaces:**
- Consumes: `BattleWidgetSnapshot`, `SharedSnapshotStore`
- Produces:
  - `GoalMode: String, Codable, CaseIterable, Sendable` (`.strictAbstinence`, `.moderationBudget`)
  - `CheckInOutcomeType: String, Codable, Sendable` (`.soberAttack`, `.withinBudgetDrink`, `.honestShieldRelapse`)
  - `RelapseTriggerTag: String, Codable, CaseIterable, Identifiable, Sendable` (6 tags from spec)
  - `MonsterSpec: Identifiable, Hashable, Sendable` (`level: Int`, `name: String`, `titleReward: String`, `maxHP: Int`, `suggestedDays: Int`, `subtitle: String`, `symbolName: String`, `accentHex: String`)
  - `MonsterCatalog.all: [MonsterSpec]`, `MonsterCatalog.spec(forLevel: Int) -> MonsterSpec`
  - `@Model final class PlayerProgress` & `@Model final class CheckInRecord`
  - `CombatActionResult` (`outcome`, `hpDelta`, `defeatedMonster: MonsterSpec?`, `promotedToLevel: Int?`, `completedCampaign: Bool`, `didAdvanceVirtualDay: Bool`)
  - `CombatEngine` (`effectiveToday(for:now:)`, `weeklyDrinksUsed(progress:records:)`, `previewAttackDamage(for:)`, `willExceedModerationBudget(progress:records:)`, `logSoberAttack(progress:records:now:)`, `logDrink(progress:records:units:triggers:note:now:)`, `rematchMonster(level:progress:)`, `applyDemoPreset(_:context:now:)`, `impactSummary(progress:)`)

- [ ] **Step 1: 先撰寫完整的 `CombatEngineTests.swift` 涵蓋所有規格與 Review Focus 案例**
  - `testSoberAttackDamageAndComboCap`: base 100, streak 3 -> 130, streak 10 -> capped at 150.
  - `testDefeatMonsterPromotesToFullHPWithoutCarryover`: Lv.1 (HP 90) hit for 100 -> defeats Lv.1, advances to Lv.2 at exact 700/700 HP (no overflow damage carried over).
  - `testStrictAbstinenceDrinkTriggersHonestShieldAndCapsHeal`: `units = 10` on Lv.2 (maxHP 700) heals capped `140` (20%), never drops below current level, resets streak to 0 while keeping `totalCleanCheckIns` & `honestShieldCount += 1` & `insightXP += 25`.
  - `testModerationBudgetWithinLimitPreservesStreakAndResetsNextWeek`: within `2/week` budget uses `withinBudgetDrink` (`units * 15` capped at 10% maxHP) and preserves `currentStreak`; at `2/2`, next drink triggers `honestShieldRelapse`; advancing to next week resets weekly usage count to 0; switching from strict to moderation mid-week counts existing drinks from that week.
  - `testCampaignCompletionAndRematchPreservesLifetimeStats`: defeating Lv.4 sets `hasCompletedCampaign = true`, then `rematchMonster(level: 1, progress:)` resets active level/HP to Lv.1 `300/300` while preserving `totalCleanCheckIns`, `totalMonstersDefeated`, `honestShieldCount`, `insightXP`, and `currentStreak`.
  - `testDemoRapidModeAdvancesVirtualDayOnRepeatTapWhileStrictModeLocks`: first tap keeps `virtualDayOffset == 0`, second tap advances `virtualDayOffset == 1`; with `demoRapidMode == false`, second tap returns `.alreadyCheckedInToday` without mutating state.
- [ ] **Step 2: 實作 `Models.swift`, `MonsterCatalog.swift`, `CombatEngine.swift`**
- [ ] **Step 3: 執行 `xcodebuild test` 驗證全部 Domain 單元測試通過**
  - Expected: All tests in `CombatEngineTests` and `SharedSnapshotStoreTests` PASS.
- [ ] **Step 4: Git 提交 Task 2**
  - `git add ... && git commit -m "實作破曉戰記資料模型、怪獸圖鑑與 RPG 戰鬥引擎（含單元測試）"`

---

### Task 3: 主戰場與動畫體驗（Battle Arena + Honest Shield + Level Up）

**Files:**
- Create: `QuitDrinking/Features/Battle/MonsterAvatarView.swift`
- Create: `QuitDrinking/Features/Battle/HonestShieldSheet.swift`
- Create: `QuitDrinking/Features/Battle/LevelUpCelebrationView.swift`
- Create: `QuitDrinking/Features/Battle/BattleArenaView.swift`

**Interfaces:**
- Consumes: `PlayerProgress`, `CheckInRecord`, `MonsterCatalog`, `CombatEngine`, `ThemeTokens`, `TactileButtonStyles`
- Produces:
  - `MonsterAvatarView(level: Int, hpRatio: Double, hitTrigger: Int, shieldTrigger: Int)`
  - `HonestShieldSheet(progress: PlayerProgress, willTriggerShield: Bool, onSubmit: (_ units: Int, _ triggers: [RelapseTriggerTag], _ note: String) -> Void)`
  - `LevelUpCelebrationView(defeatedMonster: MonsterSpec, nextMonster: MonsterSpec?, completedCampaign: Bool, onContinue: () -> Void)`
  - `BattleArenaView(progress: PlayerProgress, records: [CheckInRecord], onOpenDemo: () -> Void)`

- [ ] **Step 1: 實作 `MonsterAvatarView.swift`**
  - Craft 4 distinct stylized SwiftUI vector + SF Symbol monsters (琥珀氣泡史萊姆、重裝啤酒哥布林、紫紅宿醉巨龍、暗夜破曉心魔魔王) that visually react to `hpRatio`, animate hit recoil/flash (`PhaseAnimator` / spring respecting `accessibilityReduceMotion`), and render a translucent amber Honest Shield dome on `shieldTrigger`.
- [ ] **Step 2: 實作 `HonestShieldSheet.swift` 與 `LevelUpCelebrationView.swift`**
  - `HonestShieldSheet`: Dynamic preview banner ("仍在安全額度內，連勝不斷！" vs "將開啟誠實護盾・紀錄誘因擋下反撲"), cup stepper `1...6`, multi-select trigger chips (`LazyVGrid`), optional short reflection field, and clear action CTA.
  - `LevelUpCelebrationView`: Tactile victory overlay celebrating defeated monster, unlocked title badge, next monster preview (or campaign clear crown state), and single primary continue button.
- [ ] **Step 3: 實作 `BattleArenaView.swift`**
  - Top bar: App title (`longPressGesture` opens Demo sheet even in pure recording mode), interactive Goal Mode capsule (`[完全斷酒]` / `[減量 1/2]`), and conditional `[Demo]` button (hidden when `pureRecordingMode == true`).
  - Monster header + tabular-digit HP bar + floating `-130 暴擊!` / `+45 護盾守護` delta callout.
  - Bottom action dock: Tactile mint primary CTA (`今日沒喝・發動攻擊 (-130)`) + amber outline secondary CTA (`今天有喝・誠實紀錄`), `.sensoryFeedback` triggers, friendly daily-lock toast banner when strict mode blocks repeat tap, and accessible labels.
- [ ] **Step 4: 執行 `xcodebuild build` 確認 Task 3 編譯無警告無錯誤**
- [ ] **Step 5: Git 提交 Task 3**
  - `git add ... && git commit -m "實作主戰場、向量怪獸動效、誠實護盾表單與晉級慶祝介面"`

---

### Task 4: Swift Charts 戰績儀表板與可再戰怪獸圖鑑

**Files:**
- Create: `QuitDrinking/Features/Insights/InsightsDashboardView.swift`
- Create: `QuitDrinking/Features/Insights/MonsterBestiaryView.swift`

**Interfaces:**
- Consumes: `PlayerProgress`, `CheckInRecord`, `MonsterCatalog`, `CombatEngine`, `ThemeTokens`
- Produces: `InsightsDashboardView(progress: PlayerProgress, records: [CheckInRecord])`, `MonsterBestiaryView(progress: PlayerProgress, onRematch: (Int) -> Void)`

- [ ] **Step 1: 實作 `InsightsDashboardView.swift`**
  - Hero 2-card grid: Cumulative Money Saved (`NT$ ...`) & Calories Avoided (`... kcal` / `約 ... 碗白飯`), plus quick inline button to adjust personal per-drink cost & kcal baseline.
  - Swift Charts 7-day combat bar chart (`Chart` + `BarMark`) bucketed by the last 7 simulated calendar days relative to `CombatEngine.effectiveToday`, color-coded cleanly (`清醒攻擊` mint, `額度內小酌` sky blue, `誠實護盾` amber) with custom legend.
  - Relapse trigger insight breakdown bars (aggregated from `honestShieldRelapse` records) with encouraging empty state when 0 relapses have occurred.
- [ ] **Step 2: 實作 `MonsterBestiaryView.swift`**
  - Vertical progression timeline for Lv.1–Lv.4 displaying status (`已擊敗` + earned title + Rematch button when unlocked / campaign completed, `交戰中` + live HP bar, `未解鎖` mystery silhouette + unlock condition).
- [ ] **Step 3: 執行 `xcodebuild build` 驗證圖表與圖鑑畫面編譯通過**
- [ ] **Step 4: Git 提交 Task 4**
  - `git add ... && git commit -m "實作 Swift Charts 戰績儀表板與可再戰怪獸圖鑑頁"`

---

### Task 5: MAIC Demo 控制台、Onboarding 引導頁、Root 導航與 WidgetKit Extension

**Files:**
- Create: `QuitDrinking/Features/Demo/MAICDemoSheet.swift`
- Create: `QuitDrinking/Features/Demo/OnboardingSheetView.swift`
- Create: `QuitDrinking/RootTabView.swift`
- Modify: `QuitDrinking/App/QuitDrinkingApp.swift`
- Create: `QuitDrinkingWidget/QuitDrinkingWidgetBundle.swift`
- Create: `QuitDrinkingWidget/MonsterStatusWidget.swift`
- Create: `QuitDrinkingWidget/Info.plist`

**Interfaces:**
- Consumes: `PlayerProgress`, `CheckInRecord`, `CombatEngine`, `SharedSnapshotStore`, `BattleArenaView`, `InsightsDashboardView`, `MonsterBestiaryView`
- Produces: Complete wired 3-tab app (`TabView` using iOS 18+/27.2 `Tab` API) + working `QuitDrinkingWidget` supporting `.systemSmall`, `.systemMedium`, and `.accessoryRectangular`.

- [ ] **Step 1: 實作 `OnboardingSheetView.swift` 與 `MAICDemoSheet.swift`**
  - `OnboardingSheetView`: 1-page setup sheet for `GoalMode`, `weeklySessionLimit`, `costPerDrinkNTD`, `caloriesPerDrink`.
  - `MAICDemoSheet`: 4 Preset buttons (`初登場滿血`、`精彩殘血晉級`、`誠實護盾待命`、`一週豐富戰績`), `重置為全新玩家`, `Demo 快速演練模式` toggle, `純淨錄影模式（隱藏 Demo 按鈕）` toggle, and `演示首次引導頁` trigger.
- [ ] **Step 2: 實作 `RootTabView.swift` 與更新 `QuitDrinkingApp.swift`**
  - Initialize `ModelContainer(for: PlayerProgress.self, CheckInRecord.self)` and auto-seed a single default `PlayerProgress` on first launch, syncing `SharedSnapshotStore` + `WidgetCenter.shared.reloadAllTimelines()` on launch and changes.
  - Use SwiftUI `TabView(selection:)` with `Tab("戰場", systemImage: "flame.fill", value: .battle)` etc., styled cleanly for dark twilight canvas.
- [ ] **Step 3: 實作 `QuitDrinkingWidget`（`QuitDrinkingWidgetBundle.swift` & `MonsterStatusWidget.swift`）**
  - Implement `TimelineProvider` reading `SharedSnapshotStore.load()` and rendering compact RPG monster level, HP bar, and streak across `.systemSmall`, `.systemMedium`, and `.accessoryRectangular` using `.containerBackground(...)`.
- [ ] **Step 4: 執行 `xcodebuild test` 與 `xcodebuild build` 驗證全專案兩個 Target 編譯與測試全部通過**
- [ ] **Step 5: Git 提交 Task 5**
  - `git add ... && git commit -m "完成 MAIC Demo 控制台、Onboarding 引導頁、三頁籤導航與 WidgetKit 小工具"`

---

### Task 6: 團隊專案 Skill 建立（`/skill-creator`）與裝置／模擬器端到端驗證

**Files:**
- Create: `.agents/skills/quitdrinking-maic-rules/SKILL.md`

- [ ] **Step 1: 依 `skill-creator` 規範建立 `.agents/skills/quitdrinking-maic-rules/SKILL.md`**
  - Encode the non-negotiable rules (Swift/SwiftUI only, no punitive resets, `CombatEngine` formula invariants, `ThemeTokens` palette, 4-member directory ownership, and MAIC Demo state guidelines) in concise imperative form under 500 lines.
- [ ] **Step 2: 執行最終單元測試、裝置／模擬器探索與建置部署驗證**
  - Run `xcodebuild test` on iOS Simulator (`QuitDrinkingTests`).
  - Detect physical devices and available iOS 27.2 Simulators; build, install, and launch `QuitDrinking` on the matching device or latest Simulator, and inspect visual launch state.
- [ ] **Step 3: 執行代碼審查確認無未提交修改、無設計紅線違規**
- [ ] **Step 4: Git 提交 Task 6**
  - `git add ... && git commit -m "新增專案專屬開發 Skill 與完成模擬器建置驗證"`
