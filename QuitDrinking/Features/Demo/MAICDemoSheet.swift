import SwiftUI
import SwiftData

/// MAIC 簡報錄影專用模擬控制台：支援 4 組一鍵場景切換、模擬演練模式開關與純淨錄影隱藏控制。
struct MAICDemoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var progress: PlayerProgress
    let records: [CheckInRecord]
    let onOpenOnboarding: () -> Void

    @State private var selectedPreset = MAICDemoPreset.freshStart
    @State private var confirmReplacement = false
    @State private var showSaveError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MAICDemoPreset.allCases) { preset in
                        Button {
                            select(preset)
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
                    Text("套用預設會以範例進度與紀錄取代目前的戰績。")
                }

                Section("時間軸與錄影控制") {
                    Toggle("Demo 快速演練模式（連續打卡）", isOn: $progress.demoRapidMode)
                        .tint(ThemeTokens.mintVitality)
                        .onChange(of: progress.demoRapidMode) { _, _ in
                            saveSettings()
                        }

                    Toggle("純淨錄影模式（隱藏 Demo 按鈕）", isOn: $progress.pureRecordingMode)
                        .tint(ThemeTokens.amberShield)
                        .onChange(of: progress.pureRecordingMode) { _, _ in
                            saveSettings()
                        }

                    if progress.goalMode == .moderationBudget {
                        Stepper(value: $progress.weeklySessionLimit, in: 1...4) {
                            Text("減量週額度：每週 \(progress.weeklySessionLimit) 次")
                                .monospacedDigit()
                        }
                        .onChange(of: progress.weeklySessionLimit) { _, _ in
                            saveSettings()
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
                        select(.freshStart)
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
        .confirmationDialog("取代目前的戰績？", isPresented: $confirmReplacement, titleVisibility: .visible) {
            Button("套用預設並取代紀錄", role: .destructive) { apply(selectedPreset) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這會移除目前的打卡紀錄，並載入「\(selectedPreset.title)」。")
        }
        .alert("無法儲存變更", isPresented: $showSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("請確認裝置的可用空間後再試一次。")
        }
    }

    private func select(_ preset: MAICDemoPreset) {
        if records.isEmpty && progress.totalCleanCheckIns == 0 && progress.honestShieldCount == 0 {
            apply(preset)
        } else {
            selectedPreset = preset
            confirmReplacement = true
        }
    }

    private func apply(_ preset: MAICDemoPreset) {
        do {
            try CombatEngine.applyDemoPreset(preset, progress: progress, context: modelContext)
            dismiss()
        } catch {
            showSaveError = true
        }
    }

    private func saveSettings() {
        guard modelContext.hasChanges else { return }
        do {
            try CombatEngine.saveAndSync(progress: progress, records: records, context: modelContext)
        } catch {
            showSaveError = true
        }
    }
}
