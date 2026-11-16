import SwiftUI
import SwiftData
import WidgetKit

/// MAIC 簡報錄影專用模擬控制台：支援 4 組一鍵場景切換、模擬演練模式開關與純淨錄影隱藏控制。
struct MAICDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var progress: PlayerProgress
    let records: [CheckInRecord]
    let onOpenOnboarding: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MAICDemoPreset.allCases) { preset in
                        Button {
                            CombatEngine.applyDemoPreset(
                                preset,
                                progress: progress,
                                existingRecords: records,
                                context: modelContext
                            )
                            WidgetCenter.shared.reloadAllTimelines()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title)
                                    .font(ThemeTokens.roundedTitleFont(.subheadline, weight: .bold))
                                    .foregroundStyle(ThemeTokens.inkPrimary)
                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(ThemeTokens.inkSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("MAIC 簡報錄影快速預設")
                } footer: {
                    Text("點選會直接更新本地資料與桌面 Widget 快照，方便配合 Keynote 轉場錄影。")
                }

                Section("時間軸與錄影控制") {
                    Toggle("Demo 快速演練模式（連續打卡）", isOn: $progress.demoRapidMode)
                        .tint(ThemeTokens.mintVitality)
                        .onChange(of: progress.demoRapidMode) { _, _ in
                            try? modelContext.save()
                        }

                    Toggle("純淨錄影模式（隱藏 Demo 按鈕）", isOn: $progress.pureRecordingMode)
                        .tint(ThemeTokens.amberShield)
                        .onChange(of: progress.pureRecordingMode) { _, _ in
                            try? modelContext.save()
                        }

                    if progress.goalMode == .moderationBudget {
                        Stepper(value: $progress.weeklySessionLimit, in: 1...4) {
                            Text("減量週額度：每週 \(progress.weeklySessionLimit) 次")
                                .monospacedDigit()
                        }
                        .onChange(of: progress.weeklySessionLimit) { _, _ in
                            try? modelContext.save()
                            CombatEngine.syncSnapshot(progress: progress, records: records)
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                }

                Section("簡報開場與重置") {
                    Button {
                        dismiss()
                        onOpenOnboarding()
                    } label: {
                        Label("開啟 1 頁式 Onboarding 引導頁", systemImage: "sparkles.rectangle.stack")
                            .foregroundStyle(ThemeTokens.skyModeration)
                    }

                    Button(role: .destructive) {
                        CombatEngine.applyDemoPreset(
                            .freshStart,
                            progress: progress,
                            existingRecords: records,
                            context: modelContext
                        )
                        WidgetCenter.shared.reloadAllTimelines()
                        dismiss()
                    } label: {
                        Label("重置為全新玩家", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeTokens.canvasBackground)
            .navigationTitle("MAIC Demo 控制台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(ThemeTokens.mintVitality)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
