import SwiftUI
import SwiftData
import WidgetKit

@main
struct QuitDrinkingApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlayerProgress.self,
            CheckInRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("無法建立 SwiftData ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            BootstrapRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct BootstrapRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progresses: [PlayerProgress]
    @Query(sort: \CheckInRecord.simulatedDate, order: .forward) private var records: [CheckInRecord]

    var body: some View {
        Group {
            if let progress = progresses.first {
                RootTabView(progress: progress, records: records)
                    .onAppear {
                        CombatEngine.syncSnapshot(progress: progress, records: records)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
            } else {
                ProgressView()
                    .tint(ThemeTokens.mintVitality)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ThemeTokens.canvasBackground)
                    .onAppear {
                        let initial = PlayerProgress()
                        modelContext.insert(initial)
                        try? modelContext.save()
                        CombatEngine.syncSnapshot(progress: initial, records: [])
                        WidgetCenter.shared.reloadAllTimelines()
                    }
            }
        }
    }
}
