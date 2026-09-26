import Foundation

struct StoryCard: Identifiable, Codable, Hashable {
    var id: String
    var type: CardType {
        didSet {
            if oldValue != type { preservesOriginalType = false }
        }
    }
    var body: String
    private(set) var originalType: String?
    private(set) var preservesOriginalType: Bool
    private var sourceJSON: [String: JSONValue]

    init(id: String = UUID().uuidString, type: CardType, body: String) {
        self.id = id
        self.type = type
        self.body = body
        originalType = nil
        preservesOriginalType = false
        sourceJSON = [:]
    }

    init(from decoder: Decoder) throws {
        let value = try JSONValue(from: decoder)
        guard let source = value.objectValue else {
            throw DecodingError.typeMismatch(
                [String: JSONValue].self,
                .init(codingPath: decoder.codingPath, debugDescription: "Card must be a JSON object")
            )
        }
        sourceJSON = source
        id = source["id"]?.stringValue ?? UUID().uuidString
        originalType = source["type"]?.stringValue ?? source["cardType"]?.stringValue
        type = CardType.classify(originalType ?? "")
        body = source["text"]?.stringValue ?? source["body"]?.stringValue ?? ""
        preservesOriginalType = originalType != nil
    }

    func encode(to encoder: Encoder) throws {
        try JSONValue.object(externalJSON(order: sourceJSON["order"]?.intValue ?? 0)).encode(to: encoder)
    }

    func externalJSON(order: Int) -> [String: JSONValue] {
        var json = sourceJSON
        json["id"] = .string(id)
        json["type"] = .string(
            preservesOriginalType ? (originalType ?? type.desktopSaveValue) : type.desktopSaveValue
        )
        json["text"] = .string(body)
        if sourceJSON["body"] != nil { json["body"] = .string(body) }
        json["order"] = .integer(Int64(order))
        return json
    }
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
