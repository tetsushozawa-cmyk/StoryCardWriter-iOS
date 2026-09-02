import Foundation

struct StoryCard: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var type: CardType
    var body: String
}

struct CharacterNote: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var text: String
}

struct CharacterSection: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var notes: [CharacterNote] = []
}

struct CharacterData: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var photoBase64: String?
    var notes: [CharacterNote] = []
    var sections: [CharacterSection] = []
}
