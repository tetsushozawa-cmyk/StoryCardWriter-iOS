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

    // Retain source objects so fields introduced by another app version survive.
    var sourceJSON: [String: JSONValue] = [:]
    var sourceRootJSON: [String: JSONValue] = [:]
    var sourceWasWrapped = false

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
        let value = try JSONValue(from: decoder)
        guard let source = value.objectValue else {
            throw DecodingError.typeMismatch(
                [String: JSONValue].self,
                .init(codingPath: decoder.codingPath, debugDescription: "Story must be a JSON object")
            )
        }

        sourceJSON = source
        sourceRootJSON = source
        title = source["title"]?.stringValue ?? ""
        template = source["template"]?.stringValue
            ?? source["templateName"]?.stringValue
            ?? "Scenario"
        participantCount = min(3, max(2, source["participantCount"]?.intValue ?? 2))
        protagonistName = StoryProject.firstNonEmpty(source, keys: ["protagonistName", "heroName"])
            ?? "人物A"
        partner1Name = StoryProject.firstNonEmpty(source, keys: ["partner1Name", "partnerName"])
            ?? "人物B"
        partner2Name = StoryProject.firstNonEmpty(source, keys: ["partner2Name"]) ?? "友人"

        let decodedCards: [(sourceIndex: Int, order: Int, card: StoryCard)] = try
            (source["cards"]?.arrayValue ?? []).enumerated().compactMap { index, cardValue in
                guard let cardObject = cardValue.objectValue else { return nil }
                let data = try JSONEncoder().encode(cardValue)
                let card = try JSONDecoder().decode(StoryCard.self, from: data)
                return (index, cardObject["order"]?.intValue ?? index, card)
            }
        cards = decodedCards
            .sorted { left, right in
                left.order == right.order
                    ? left.sourceIndex < right.sourceIndex
                    : left.order < right.order
            }
            .map(\.card)

        if let characterValues = (source["characters"] ?? source["characterNotes"])?.arrayValue {
            let data = try JSONEncoder().encode(JSONValue.array(characterValues))
            characters = try JSONDecoder().decode([CharacterData].self, from: data)
        } else {
            characters = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var root: [String: JSONValue]
        if sourceWasWrapped {
            root = sourceRootJSON
            root.removeValue(forKey: "formatVersion")
            root.removeValue(forKey: "fileType")
            root.removeValue(forKey: "story")
            sourceJSON.forEach { root[$0.key] = $0.value }
        } else {
            root = sourceJSON.isEmpty ? sourceRootJSON : sourceJSON
        }

        root["title"] = .string(title)
        root["templateName"] = .string(template)
        root["participantCount"] = .integer(Int64(participantCount))
        root["protagonistName"] = .string(protagonistName)
        root["partner1Name"] = .string(partner1Name)
        root["partner2Name"] = .string(partner2Name)
        root["partnerName"] = .string(partner1Name)
        root["cards"] = .array(cards.enumerated().map { index, card in
            .object(card.externalJSON(order: index))
        })

        let charactersData = try JSONEncoder().encode(characters)
        root["characters"] = try JSONDecoder().decode(JSONValue.self, from: charactersData)
        try JSONValue.object(root).encode(to: encoder)
    }

    var availableTypes: [CardType] { CardType.quickTypes }

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

    func cardLabel(for type: CardType) -> String { type.displayName }

    private static func firstNonEmpty(
        _ source: [String: JSONValue],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = source[key]?.stringValue, !value.isEmpty { return value }
        }
        return nil
    }
}
