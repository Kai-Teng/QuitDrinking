import Foundation

/// A map stop shows the encounter in progress even when that monster was defeated in an earlier run.
struct CampaignStop: Identifiable {
    enum State: Equatable {
        case locked
        case current(hp: Int)
        case cleared

        var label: String {
            switch self {
            case .locked: "未解鎖"
            case .current: "交戰中"
            case .cleared: "已擊敗"
            }
        }

        var symbol: String {
            switch self {
            case .locked: "lock.fill"
            case .current: "flame.fill"
            case .cleared: "checkmark"
            }
        }
    }

    let spec: MonsterSpec
    let state: State
    let earnedTitle: Bool
    var id: Int { spec.level }

    static func all(for progress: PlayerProgress) -> [Self] {
        let defeated = progress.defeatedMonsterLevels
        let standby = CombatEngine.isCampaignVictoryStandby(progress)
        return MonsterCatalog.all.map { spec in
            let earned = defeated.contains(spec.level) || progress.hasCompletedCampaign
            let state: State
            if !standby && progress.activeMonsterLevel == spec.level {
                state = .current(hp: progress.currentMonsterHP)
            } else {
                state = earned ? .cleared : .locked
            }
            return Self(spec: spec, state: state, earnedTitle: earned)
        }
    }
}
