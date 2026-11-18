import Foundation

/// 定義關卡怪獸的靜態屬性與獎勵稱號。
struct MonsterSpec: Identifiable, Hashable, Sendable {
    let level: Int
    let name: String
    let titleReward: String
    let maxHP: Int
    let suggestedDays: Int
    let situation: String
    let subtitle: String
    let alternative: String
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
            situation: "下班買酒",
            subtitle: "下班走進便利商店，熟悉的那罐啤酒就在手邊。",
            alternative: "在進店前先想好，今天想帶哪一瓶無酒精飲料回家。",
            symbolName: "drop.halffull",
            accentHex: 0xF59E0B
        ),
        MonsterSpec(
            level: 2,
            name: "啤酒肚哥布林",
            titleReward: "聚餐防禦者",
            maxHP: 700,
            suggestedDays: 7,
            situation: "聚餐續杯",
            subtitle: "餐桌上有人拿起酒瓶，問：「再幫你倒一點？」",
            alternative: "先替自己倒杯水。有人勸酒時，可以說「我用這杯跟你乾杯」。",
            symbolName: "mug.fill",
            accentHex: 0x2DD4BF
        ),
        MonsterSpec(
            level: 3,
            name: "宿醉巨龍",
            titleReward: "自律騎士",
            maxHP: 1400,
            suggestedDays: 14,
            situation: "宿醉的早晨",
            subtitle: "鬧鐘響了。昨晚最後那幾杯，今天特別有感。",
            alternative: "趁還記得，寫下昨晚是哪個時刻讓你想再喝一杯。",
            symbolName: "flame.fill",
            accentHex: 0xF43F5E
        ),
        MonsterSpec(
            level: 4,
            name: "心魔魔王",
            titleReward: "破曉勇者",
            maxHP: 3000,
            suggestedDays: 30,
            situation: "睡前那一杯",
            subtitle: "洗完澡、關了燈，睡前開一瓶已經成了習慣。",
            alternative: "試著把開瓶的動作換成泡一杯無咖啡因的茶。",
            symbolName: "crown.fill",
            accentHex: 0xA855F7
        )
    ]

    static func spec(forLevel level: Int) -> MonsterSpec {
        all.first { $0.level == level } ?? all[0]
    }
}
