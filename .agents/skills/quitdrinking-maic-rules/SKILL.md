---
name: quitdrinking-maic-rules
description: Project conventions, RPG combat invariants, 4-member module boundaries, SwiftUI-only rules, and MAIC Keynote demo guidelines for the QuitDrinking (DawnQuest / 破曉戰記) iOS app. Trigger this skill whenever modifying, extending, reviewing, or debugging any Swift file, monster level, combat formula, SwiftData model, chart, widget, or demo preset in the QuitDrinking workspace.
---

# DawnQuest (破曉戰記) Project Rules & Architecture

Keep all 4 team members' edits consistent with the MAIC pitch, anti-churn psychology, and Apple HIG / iOS 27.2 standards.

## 1. Non-Negotiable Product Invariants

- **Never implement punitive resets**: Recording alcohol intake must NEVER drop `activeMonsterLevel` backward or clear lifetime `totalCleanCheckIns`, `totalDamageDealt`, `totalMonstersDefeated`, `honestShieldCount`, or `insightXP`. Traditional sobriety apps lose users through the "What-The-Hell Effect" after one slip; the entire pitch depends on Honest Shield turning slips into insight.
- **Honor the Dual-Track Goal Modes**:
  - `strictAbstinence`: Any drink triggers `honestShieldRelapse` (resets `currentStreak` to `0`, heals capped at `20%` of `maxHP`, adds `+1` shield & `+25` Insight XP).
  - `moderationBudget`: Tracks a single weekly session limit (`1...4` sessions, Monday–Sunday). Drinks strictly below the limit are `withinBudgetDrink` (minor heal capped at `10%` of `maxHP`, **preserves `currentStreak`**); drinks at or above the limit trigger `honestShieldRelapse`.
- **Keep Combat Math Centralized in `CombatEngine`**: Do not duplicate HP, combo bonus (`100 + min(streak * 10, 50)`), or budget calculations inside SwiftUI views. Call `CombatEngine` methods and invoke `CombatEngine.syncSnapshot(...)` + `WidgetCenter.shared.reloadAllTimelines()` after mutations.
- **Preserve Victory Standby & Rematch**: Defeating Lv.4 (`心魔魔王`) marks `hasCompletedCampaign = true` and enters standby (`currentMonsterHP == 0`). Rematching from `MonsterBestiaryView` calls `CombatEngine.rematchMonster(...)` and preserves all lifetime counters.

## 2. Tech Stack & Visual System

- **Pure Swift + SwiftUI (iOS 27.2 / Swift 6)**: Do not introduce UIKit/AppKit view controllers or third-party UI dependencies. Use modern SwiftUI APIs (`Tab`, `sensoryFeedback`, `keyframeAnimator`, `SwiftData`, `Charts`, `WidgetKit`).
- **Twilight Tavern to Crisp Dawn Palette**: Always pull colors from `ThemeTokens` (`#0D131F` canvas, `#162032` card surface, `#F6F3EC` primary ink, `#2DD4BF` mint attacks/savings, `#F59E0B` amber Honest Shield/crowns, `#F43F5E` coral alerts, `#38BDF8` sky moderation). Never hardcode raw hex values in feature views.
- **Typography & Accessibility**: Render dynamic HP, currency, calorie, and day numbers with `ThemeTokens.roundedNumericFont` + `.monospacedDigit()` to prevent jitter during live Keynote screen recordings. Provide `accessibilityLabel`/`accessibilityValue` on custom gauges and icon buttons, and gate non-essential bounce/shake animations with `@Environment(\.accessibilityReduceMotion)`.

## 3. Team Module Ownership (Avoid Merge Conflicts)

Respect these directory boundaries when assigning or editing work across the 4 teammates:

| Teammate Role | Owned Paths | Responsibility |
| :--- | :--- | :--- |
| Member 1 (Core & Data) | `QuitDrinking/Domain/` | `Models.swift`, `MonsterCatalog.swift`, `CombatEngine.swift`, `SharedSnapshotStore.swift` |
| Member 2 (Battle UI) | `QuitDrinking/Features/Battle/` | `BattleArenaView.swift`, `MonsterAvatarView.swift`, `HonestShieldSheet.swift`, `LevelUpCelebrationView.swift` |
| Member 3 (Insights & Bestiary) | `QuitDrinking/Features/Insights/` | `InsightsDashboardView.swift`, `MonsterBestiaryView.swift` |
| Member 4 (MAIC Demo & System) | `QuitDrinking/Features/Demo/`, `QuitDrinkingWidget/` | `MAICDemoSheet.swift`, `OnboardingSheetView.swift`, `MonsterStatusWidget.swift` |

Shared files (`QuitDrinkingApp.swift`, `RootTabView.swift`, `DesignSystem/*`) should only be changed with cross-team agreement.

## 4. Widget & MAIC Keynote Recording Guidelines

- **Safe Widget Fallback**: Keep `SharedSnapshotStore` capable of falling back to `UserDefaults.standard` and `.placeholder` when an App Group capability is unavailable under a personal signing team.
- **Demo Clock & Pure Recording Mode**: Use `virtualDayOffset` + `demoRapidMode` so consecutive taps advance simulated calendar days for 7-day Swift Charts demos. Before recording 60fps simulator clips for Keynote Magic Move slides, enable `pureRecordingMode` in `MAICDemoSheet` to hide the top-right Demo icon (long-press the `DawnQuest` title to re-open it anytime).

## 5. Verification Before Committing

Run unit tests and simulator builds whenever modifying `Domain/` or shared interfaces:

```bash
xcodebuild test -project QuitDrinking.xcodeproj -scheme QuitDrinking -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```
