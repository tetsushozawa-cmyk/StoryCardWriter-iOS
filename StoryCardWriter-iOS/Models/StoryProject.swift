import Foundation

struct StoryProject: Codable, Hashable {
    var title: String = ""
    var template: String = "Scenario"
    var participantCount: Int = 2
    var protagonistName: String = "人物A"
    var partner1Name: String = "人物B"
    var partner2Name: String = "友人"
    var cards: [StoryCard] = []
    var characters: [CharacterData] = []

    enum CodingKeys: String, CodingKey {
        case title, template, templateName, participantCount, protagonistName, heroName
        case partner1Name, partnerName, partner2Name, cards, characters, characterNotes
    }

    init(
        title: String = "",
        template: String = "Scenario",
        participantCount: Int = 2,
        protagonistName: String = "人物A",
        partner1Name: String = "人物B",
        partner2Name: String = "友人",
        cards: [StoryCard] = [],
        characters: [CharacterData] = []
    ) {
        self.title = title
        self.template = template
        self.participantCount = participantCount
        self.protagonistName = protagonistName
        self.partner1Name = partner1Name
        self.partner2Name = partner2Name
        self.cards = cards
        self.characters = characters
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        title = try box.decodeIfPresent(String.self, forKey: .title) ?? ""
        template = try box.decodeIfPresent(String.self, forKey: .template)
            ?? box.decodeIfPresent(String.self, forKey: .templateName) ?? "Scenario"
        participantCount = min(3, max(2, try box.decodeIfPresent(Int.self, forKey: .participantCount) ?? 2))
        protagonistName = try box.decodeIfPresent(String.self, forKey: .protagonistName)
            ?? box.decodeIfPresent(String.self, forKey: .heroName) ?? "人物A"
        partner1Name = try box.decodeIfPresent(String.self, forKey: .partner1Name)
            ?? box.decodeIfPresent(String.self, forKey: .partnerName) ?? "人物B"
        partner2Name = try box.decodeIfPresent(String.self, forKey: .partner2Name) ?? "友人"
        cards = try box.decodeIfPresent([StoryCard].self, forKey: .cards) ?? []
        characters = try box.decodeIfPresent([CharacterData].self, forKey: .characters)
            ?? box.decodeIfPresent([CharacterData].self, forKey: .characterNotes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(title, forKey: .title)
        try box.encode(template, forKey: .template)
        try box.encode(participantCount, forKey: .participantCount)
        try box.encode(protagonistName, forKey: .protagonistName)
        try box.encode(partner1Name, forKey: .partner1Name)
        try box.encode(partner2Name, forKey: .partner2Name)
        try box.encode(protagonistName, forKey: .heroName)
        try box.encode(partner1Name, forKey: .partnerName)
        try box.encode(cards, forKey: .cards)
        try box.encode(characters, forKey: .characters)
    }

    var availableTypes: [CardType] {
        participantCount == 3
            ? [.hero, .partner, .partner2, .narration]
            : [.hero, .partner, .narration, .action]
    }

    func characterName(_ id: String) -> String {
        switch id {
        case "protagonist": protagonistName
        case "partner1": partner1Name
        case "partner2": partner2Name
        default: id
        }
    }

    func character(_ id: String) -> CharacterData {
        var value = characters.first(where: { $0.id == id })
            ?? CharacterData(id: id, name: characterName(id))
        value.name = characterName(id)
        return value
    }

    mutating func updateCharacter(_ character: CharacterData) {
        characters.removeAll { $0.id == character.id }
        var updated = character
        updated.name = characterName(character.id)
        characters.append(updated)
    }

    func speakerName(for type: CardType) -> String {
        switch type {
        case .hero: protagonistName
        case .partner: partner1Name
        case .partner2: partner2Name
        case .narration: "ナレーション"
        case .action: "アクション"
        }
    }
}
