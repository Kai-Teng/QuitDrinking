import SwiftUI
import SwiftData

@main
struct QuitDrinkingApp: App {
    @State private var store: Result<ModelContainer, Error>?

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                BootstrapRootView()
                    .modelContainer(container)
            case .failure:
                StorageErrorView(retry: openStore)
            case nil:
                ProgressView("正在開啟戰績")
                    .task { openStore() }
            }
        }
    }

    private func openStore() {
        let schema = Schema([PlayerProgress.self, CheckInRecord.self])
        #if DEBUG
        let inMemory = ProcessInfo.processInfo.arguments.contains("-UITestInMemoryStore")
        #else
        let inMemory = false
        #endif
        // App Group 僅共享 Widget 快照。既有玩家的資料庫繼續使用主 App 容器。
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, groupContainer: .none)
        store = Result { try ModelContainer(for: schema, configurations: [configuration]) }
    }
}

private struct BootstrapRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckInRecord.simulatedDate) private var records: [CheckInRecord]
    @State private var progress: PlayerProgress?
    @State private var loadFailed = false

    var body: some View {
        if let progress {
            RootTabView(progress: progress, records: records)
        } else if loadFailed {
            StorageErrorView(retry: loadProgress)
        } else {
            ProgressView("正在讀取戰績")
                .task { loadProgress() }
        }
    }

    private func loadProgress() {
        do {
            var query = FetchDescriptor<PlayerProgress>(sortBy: [SortDescriptor(\PlayerProgress.createdAt)])
            query.fetchLimit = 1
            if let existing = try modelContext.fetch(query).first {
                progress = existing
            } else {
                let initial = PlayerProgress()
                modelContext.insert(initial)
                try modelContext.save()
                progress = initial
            }
            if let progress {
                CombatEngine.syncSnapshot(progress: progress, records: records)
            }
        } catch {
            modelContext.rollback()
            loadFailed = true
        }
    }
}

private struct StorageErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("無法開啟戰績", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("請確認裝置的可用空間後重試。")
        } actions: {
            Button("重試", action: retry)
        }
    }
}
