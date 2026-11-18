import SwiftUI

/// 一次飲酒紀錄。杯數、情境與備忘在成功儲存前都是草稿。
struct HonestShieldSheet: View {
    let monsterSpec: MonsterSpec
    let willTriggerShield: Bool
    let currentHP: Int
    let weeklyUsed: Int
    let weeklyLimit: Int
    let isModerationMode: Bool
    let onSubmit: (_ units: Int, _ triggers: [RelapseTriggerTag], _ note: String) throws -> CombatActionStatus

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var saveFailed = false
    @State private var submitNeedsTrigger = false
    @State private var units: Int = 1
    @State private var selectedTriggers: Set<RelapseTriggerTag> = []
    @State private var note: String = ""

    private var showsShield: Bool { willTriggerShield || submitNeedsTrigger }

    private var predictedHeal: Int {
        CombatEngine.appliedHealAmount(
            units: units, monsterMaxHP: monsterSpec.maxHP, currentHP: currentHP, triggersShield: showsShield
        )
    }

    private var canSubmit: Bool {
        !showsShield || !selectedTriggers.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    unitsSection
                    rule
                    triggersSection
                    rule
                    noteSection
                    statusSummary
                }
                .padding(22)
                .frame(maxWidth: 550)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(ThemeTokens.receiptInk)
            .background(ThemeTokens.receiptPaper)
            .navigationTitle("飲酒紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ThemeTokens.receiptPaper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(ThemeTokens.receiptInk)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("記下這次飲酒", action: submit)
                    .buttonStyle(TactilePrimaryButtonStyle(fillColor: ThemeTokens.printGreen,
                                                         foregroundColor: ThemeTokens.receiptPaper))
                    .accessibilityIdentifier("drink.submit")
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.46)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 550)
                    .frame(maxWidth: .infinity)
                    .background(ThemeTokens.receiptPaper)
            }
        }
        .preferredColorScheme(.light)
        .alert("紀錄未儲存", isPresented: $saveFailed) {
            Button("好", role: .cancel) {}
        } message: {
            Text("表單內容已保留，請再試一次。")
        }
    }

    private func submit() {
        do {
            let tags = RelapseTriggerTag.allCases.filter(selectedTriggers.contains)
            let status = try onSubmit(units, tags, note.trimmingCharacters(in: .whitespacesAndNewlines))
            if case .requiresTrigger = status {
                submitNeedsTrigger = true
            } else {
                dismiss()
            }
        } catch {
            saveFailed = true
        }
    }

    private var rule: some View {
        Divider().overlay(ThemeTokens.receiptInk.opacity(0.30))
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("這次喝了幾杯？")
                .font(.system(.title, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Stepper(value: $units, in: 1...6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(units == 6 ? "6+" : "\(units)")
                        .font(ThemeTokens.roundedTitleFont(.largeTitle)).monospacedDigit()
                    Text("標準杯")
                        .font(.subheadline)
                }
            }
            .accessibilityLabel("飲酒杯數")
            .accessibilityValue(units == 6 ? "六標準杯以上" : "\(units) 標準杯")

            DisclosureGroup("一標準杯有多少？") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("這裡以 10 公克純酒精為一標準杯。依瓶身標示的濃度，可用下列份量估算。")
                    LabeledContent("啤酒（5%）", value: "約 250 mL")
                    LabeledContent("葡萄酒（12%）", value: "約 100 mL")
                    LabeledContent("威士忌（40%）", value: "約 30 mL")
                    if let source = URL(string: "https://www.mohw.gov.tw/dl-58612-ae275510-f3ab-4327-9b2d-b6976d0f20ef.html") {
                        Link("衛福部・常見酒類之酒精含量表", destination: source)
                            .underline()
                    }
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .font(.subheadline)
            .tint(ThemeTokens.printGreen)
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("當時是什麼情境？")
                .font(.headline)
            Text(showsShield ? "誠實護盾需要至少一項，可複選。" : "可以複選，也可以略過。")
                .font(.subheadline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                     count: dynamicTypeSize >= .xxxLarge ? 1 : 2),
                      alignment: .leading, spacing: 0) {
                ForEach(RelapseTriggerTag.allCases) { tag in
                    let selected = selectedTriggers.contains(tag)
                    Button {
                        if selected { selectedTriggers.remove(tag) } else { selectedTriggers.insert(tag) }
                    } label: {
                        Label(tag.rawValue, systemImage: selected ? "checkmark.square.fill" : "square")
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selected ? ThemeTokens.printGreen : ThemeTokens.receiptInk)
                    .accessibilityLabel(tag.rawValue)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("留一句給自己（選填）")
                .font(.headline)
            TextField("例如：第二輪有人幫我把酒添滿了。", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityLabel("給自己的備忘")
            rule
        }
    }

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(showsShield ? "這次會啟動誠實護盾" : "這次在每週減量目標內",
                  systemImage: showsShield ? "shield.lefthalf.filled" : "checkmark")
                .font(.headline)
            if showsShield {
                Text("關卡與累計成果保留，連勝重新起算。\(monsterSpec.name)回復 \(predictedHeal) HP。")
            } else if isModerationMode {
                Text("本週已記 \(weeklyUsed) 次，上限為 \(weeklyLimit) 次。這次保留連勝，怪獸回復 \(predictedHeal) HP。")
            }
        }
        .font(.subheadline)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }
}
