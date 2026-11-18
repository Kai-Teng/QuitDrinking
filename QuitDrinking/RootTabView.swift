import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case battle
    case campaign
    case insights
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext

    let progress: PlayerProgress
    let records: [CheckInRecord]

    @State private var selectedTab: RootTab = .battle
    @State private var showDemoSheet = false
    @State private var showOnboardingSheet = false
    @State private var openOnboardingAfterDemo = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("戰場", systemImage: "flame.fill", value: .battle) {
                BattleArenaView(
                    progress: progress,
                    records: records,
                    isStageVisible: selectedTab == .battle && !showDemoSheet && !showOnboardingSheet,
                    onOpenDemo: { showDemoSheet = true },
                    onOpenCampaign: { selectedTab = .campaign }
                )
            }

            Tab("關卡", systemImage: "map.fill", value: .campaign) {
                CampaignMapView(progress: progress, onOpenBattle: { selectedTab = .battle }) { level in
                    if CombatEngine.rematchMonster(level: level, progress: progress) {
                        try CombatEngine.saveAndSync(progress: progress, records: records, context: modelContext)
                    }
                }
            }

            Tab("戰績", systemImage: "chart.bar.fill", value: .insights) {
                InsightsDashboardView(progress: progress, records: records)
            }
        }
        .tint(ThemeTokens.mintVitality)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDemoSheet, onDismiss: {
            if openOnboardingAfterDemo {
                openOnboardingAfterDemo = false
                showOnboardingSheet = true
            }
        }) {
            MAICDemoSheet(progress: progress, records: records) {
                openOnboardingAfterDemo = true
            }
        }
        .sheet(isPresented: $showOnboardingSheet) {
            OnboardingSheetView(progress: progress, records: records)
        }
    }
}
