import SwiftUI
import SwiftData
import WidgetKit

enum RootTab: Hashable {
    case battle
    case insights
    case bestiary
}

/// 三頁籤黃金畫面導航容器。
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext

    let progress: PlayerProgress
    let records: [CheckInRecord]

    @State private var selectedTab: RootTab = .battle
    @State private var showDemoSheet = false
    @State private var showOnboardingSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("戰場", systemImage: "flame.fill", value: .battle) {
                BattleArenaView(
                    progress: progress,
                    records: records,
                    onOpenDemo: { showDemoSheet = true },
                    onOpenBestiary: { selectedTab = .bestiary }
                )
            }

            Tab("戰績", systemImage: "chart.bar.fill", value: .insights) {
                InsightsDashboardView(progress: progress, records: records)
            }

            Tab("圖鑑", systemImage: "book.closed.fill", value: .bestiary) {
                MonsterBestiaryView(progress: progress) { level in
                    CombatEngine.rematchMonster(level: level, progress: progress, records: records)
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                    selectedTab = .battle
                }
            }
        }
        .tint(ThemeTokens.mintVitality)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDemoSheet) {
            MAICDemoSheet(
                progress: progress,
                records: records,
                onOpenOnboarding: {
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        showOnboardingSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showOnboardingSheet) {
            OnboardingSheetView(progress: progress) {
                try? modelContext.save()
                CombatEngine.syncSnapshot(progress: progress, records: records)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
