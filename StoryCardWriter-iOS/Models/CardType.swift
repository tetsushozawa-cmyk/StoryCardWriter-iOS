import SwiftUI

enum CardType: String, Codable, CaseIterable, Hashable {
    case hero = "Hero"
    case partner = "Partner"
    case partner2 = "Partner2"
    case narration = "Narration"
    case action = "Action"

    var displayName: String {
        switch self {
        case .hero: "主人公"
        case .partner: "相手役1"
        case .partner2: "相手役2"
        case .narration: "ナレーション"
        case .action: "アクション"
        }
    }

    var color: Color {
        switch self {
        case .hero: Color(red: 0.10, green: 0.36, blue: 0.66)
        case .partner: Color(red: 0.15, green: 0.45, blue: 0.23)
        case .partner2: Color(red: 0.44, green: 0.23, blue: 0.58)
        case .narration: Color(red: 0.34, green: 0.36, blue: 0.40)
        case .action: Color(red: 0.61, green: 0.36, blue: 0.08)
        }
    }
}
