import Foundation

enum CardType: String, Codable, CaseIterable, Hashable {
    case subject
    case idea
    case target
    case reference
    case opinion
    case decision
    case legacyHero
    case legacyPartner2
    case unknown

    static let quickTypes: [CardType] = [.idea, .target, .reference, .opinion]

    static func classify(_ savedValue: String) -> CardType {
        switch savedValue {
        case "主人公", "Protagonist": .subject
        case "相手", "Partner": .idea
        case "ナレーション", "Narration": .target
        case "アクション", "Action": .reference
        case "心情", "Emotion": .opinion
        case "効果音", "SoundEffect": .decision
        case "Hero": .legacyHero
        case "Partner2": .legacyPartner2
        default: .unknown
        }
    }

    var desktopSaveValue: String {
        switch self {
        case .subject: "主人公"
        case .idea: "相手"
        case .target: "ナレーション"
        case .reference: "アクション"
        case .opinion: "心情"
        case .decision: "効果音"
        case .legacyHero: "Hero"
        case .legacyPartner2: "Partner2"
        case .unknown: "Unknown"
        }
    }

    var displayName: String {
        switch self {
        case .subject, .legacyHero: "主題"
        case .idea: "アイデア"
        case .target, .legacyPartner2, .unknown: "対象"
        case .reference: "参考"
        case .opinion: "意見"
        case .decision: "決定"
        }
    }

}
