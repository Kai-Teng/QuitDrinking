import Foundation

/// 定義關卡怪獸的靜態屬性與獎勵稱號。
struct MonsterSpec: Identifiable, Hashable, Sendable {
    let level: Int
    let name: String
    let titleReward: String
    let maxHP: Int
    let suggestedDays: Int
    let subtitle: String
    let symbolName: String
    let accentHex: UInt32

    var id: Int { level }
}

/// 破曉戰記 Lv.1～Lv.4 怪獸關卡目錄。
enum MonsterCatalog {
    static let all: [MonsterSpec] = [
        MonsterSpec(
            level: 1,
            name: "微醺史萊姆",
            titleReward: "清醒見習生",
            maxHP: 300,
            suggestedDays: 3,
            subtitle: "把前幾天的忍耐化為第一道破曉微光",
            symbolName: "drop.halffull",
            accentHex: 0xF59E0B
        ),
        MonsterSpec(
            level: 2,
            name: "啤酒肚哥布林",
            titleReward: "聚餐防禦者",
            maxHP: 700,
            suggestedDays: 7,
            subtitle: "最擅長在週五聚會與乾杯起鬨時現身",
            symbolName: "mug.fill",
            accentHex: 0x2DD4BF
        ),
        MonsterSpec(
            level: 3,
            name: "宿醉巨龍",
            titleReward: "自律騎士",
            maxHP: 1400,
            suggestedDays: 14,
            subtitle: "噴吐疲憊與頭痛吐息的深夜強敵",
            symbolName: "flame.fill",
            accentHex: 0xF43F5E
        ),
        MonsterSpec(
            level: 4,
            name: "心魔魔王",
            titleReward: "破曉勇者",
            maxHP: 3000,
            suggestedDays: 30,
            subtitle: "潛伏於壓力與習慣深處的最終試煉",
            symbolName: "crown.fill",
            accentHex: 0xA855F7
        )
    ]

    static func spec(forLevel level: Int) -> MonsterSpec {
        all.first { $0.level == level } ?? all[0]
    }
}
