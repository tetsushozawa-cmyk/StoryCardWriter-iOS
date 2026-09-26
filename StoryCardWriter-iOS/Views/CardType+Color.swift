import SwiftUI

extension CardType {
    var color: Color {
        switch self {
        case .subject, .legacyHero: Color(red: 0.10, green: 0.36, blue: 0.66)
        case .idea: Color(red: 0.15, green: 0.45, blue: 0.23)
        case .target, .unknown: Color(red: 0.34, green: 0.36, blue: 0.40)
        case .reference, .decision: Color(red: 0.61, green: 0.36, blue: 0.08)
        case .opinion, .legacyPartner2: Color(red: 0.44, green: 0.23, blue: 0.58)
        }
    }
}
