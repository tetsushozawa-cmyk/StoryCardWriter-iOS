import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): message }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.failed(message) }
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw TestFailure.failed("Encoded value is not a root JSON object")
    }
    return object
}

private func cards(_ root: [String: Any]) throws -> [[String: Any]] {
    guard let value = root["cards"] as? [[String: Any]] else {
        throw TestFailure.failed("cards is missing")
    }
    return value
}

@main
enum CompatibilityTestRunner {
    static func main() throws {
        try quick4UsesDesktopValuesAndText()
        try desktopSixTypesAndTextDecode()
        try subjectAndDecisionSurviveBodyEdit()
        try legacyBodyAndMissingIDDecode()
        try unknownCardFieldsAndRootFieldsSurvive()
        try legacyTypesKeepTheirExactValues()
        try explicitClassificationChangeUsesCanonicalValue()
        try orderIsReadAndRenumbered()
        try wrapperExportsRootLevel()
        try iphoneDesktopIphoneRoundTrip()
        print("ScwCompatibilityTests: 13 compatibility requirements passed")
    }

    private static func quick4UsesDesktopValuesAndText() throws {
        let project = StoryProject(cards: CardType.quickTypes.map {
            StoryCard(type: $0, body: $0.displayName)
        })
        let root = try jsonObject(ScwCodec.encode(project))
        let savedCards = try cards(root)
        try expect(savedCards.compactMap { $0["type"] as? String } == ["相手", "ナレーション", "アクション", "心情"], "Quick 4 save values")
        try expect(savedCards.allSatisfy { $0["text"] != nil && $0["body"] == nil }, "New cards use text")
        try expect(root["story"] == nil, "External file must be root-level")
    }

    private static func desktopSixTypesAndTextDecode() throws {
        let values = ["主人公", "相手", "ナレーション", "アクション", "心情", "効果音"]
        let source = ["cards": values.enumerated().map { ["type": $0.element, "text": "body-\($0.offset)"] }]
        let data = try JSONSerialization.data(withJSONObject: source)
        let project = try ScwCodec.decode(data)
        try expect(project.cards.map(\.type) == [.subject, .idea, .target, .reference, .opinion, .decision], "Desktop six types decode")
        try expect(project.cards.map(\.body) == values.indices.map { "body-\($0)" }, "Desktop text decodes")
        try expect(project.cards.allSatisfy { !$0.id.isEmpty }, "Missing IDs are generated")

        let english = ["Protagonist", "Partner", "Narration", "Action", "Emotion", "SoundEffect"]
        let englishData = try JSONSerialization.data(withJSONObject: ["cards": english.map { ["type": $0, "text": $0] }])
        let englishProject = try ScwCodec.decode(englishData)
        try expect(englishProject.cards.map(\.type) == [.subject, .idea, .target, .reference, .opinion, .decision], "English compatibility values decode")
    }

    private static func subjectAndDecisionSurviveBodyEdit() throws {
        let data = Data(#"{"cards":[{"type":"主人公","text":"before"},{"type":"効果音","text":"before"}]}"#.utf8)
        var project = try ScwCodec.decode(data)
        project.cards[0].body = "after-subject"
        project.cards[1].body = "after-decision"
        let saved = try cards(jsonObject(ScwCodec.encode(project)))
        try expect(saved[0]["type"] as? String == "主人公", "Subject type survives")
        try expect(saved[1]["type"] as? String == "効果音", "Decision type survives")
    }

    private static func legacyBodyAndMissingIDDecode() throws {
        let data = Data(#"{"cards":[{"type":"Hero","body":"legacy"},{"type":"相手","text":"preferred","body":"fallback"}]}"#.utf8)
        var project = try ScwCodec.decode(data)
        try expect(project.cards[0].body == "legacy", "Legacy body decodes")
        try expect(project.cards[1].body == "preferred", "text has priority")
        project.cards[0].body = "edited"
        let saved = try cards(jsonObject(ScwCodec.encode(project)))
        try expect(saved[0]["text"] as? String == "edited" && saved[0]["body"] as? String == "edited", "Existing body stays synchronized")
    }

    private static func unknownCardFieldsAndRootFieldsSurvive() throws {
        let data = Data(##"{"rootExtra":{"keep":true},"cards":[{"id":"x","type":"FutureType","text":"future","label":"L","color":"#123","order":7,"futureField":[1,2]}]}"##.utf8)
        var project = try ScwCodec.decode(data)
        try expect(project.cards.single?.type == .unknown, "Unknown type decodes")
        project.cards[0].body = "edited"
        let root = try jsonObject(ScwCodec.encode(project))
        let card = try cards(root)[0]
        try expect(card["type"] as? String == "FutureType", "Unknown type value survives")
        try expect(card["label"] as? String == "L" && card["color"] as? String == "#123", "label and color survive")
        try expect((card["futureField"] as? [Int]) == [1, 2], "Unknown card field survives")
        try expect((root["rootExtra"] as? [String: Bool])?["keep"] == true, "Unknown root field survives")
    }

    private static func legacyTypesKeepTheirExactValues() throws {
        let values = ["Hero", "Partner", "Partner2", "Narration", "Action"]
        let source = ["cards": values.map { ["type": $0, "body": $0] }]
        var project = try ScwCodec.decode(JSONSerialization.data(withJSONObject: source))
        project.cards.indices.forEach { project.cards[$0].body += "!" }
        let saved = try cards(jsonObject(ScwCodec.encode(project)))
        try expect(saved.compactMap { $0["type"] as? String } == values, "Legacy type spellings survive")
    }

    private static func explicitClassificationChangeUsesCanonicalValue() throws {
        var project = try ScwCodec.decode(Data(#"{"cards":[{"type":"FutureType","text":"x"}]}"#.utf8))
        project.cards[0].type = .reference
        let card = try cards(jsonObject(ScwCodec.encode(project)))[0]
        try expect(card["type"] as? String == "アクション", "Explicit type change uses canonical value")
    }

    private static func orderIsReadAndRenumbered() throws {
        let data = Data(#"{"cards":[{"type":"相手","text":"last","order":9},{"type":"主人公","text":"first","order":1}]}"#.utf8)
        let project = try ScwCodec.decode(data)
        try expect(project.cards.map(\.body) == ["first", "last"], "Cards are sorted by order")
        let saved = try cards(jsonObject(ScwCodec.encode(project)))
        try expect((saved[0]["order"] as? NSNumber)?.intValue == 0 && (saved[1]["order"] as? NSNumber)?.intValue == 1, "Order is renumbered")
    }

    private static func wrapperExportsRootLevel() throws {
        let data = Data(#"{"formatVersion":2,"fileType":"StoryCardWriter","wrapperExtra":"keep","story":{"title":"wrapped","storyExtra":3,"cards":[{"type":"効果音","text":"x"}]}}"#.utf8)
        let root = try jsonObject(ScwCodec.encode(ScwCodec.decode(data)))
        try expect(root["story"] == nil && root["fileType"] == nil, "Wrapper is flattened")
        try expect(root["wrapperExtra"] as? String == "keep" && (root["storyExtra"] as? NSNumber)?.intValue == 3, "Wrapper and story extras survive")
    }

    private static func iphoneDesktopIphoneRoundTrip() throws {
        let original = StoryProject(cards: [StoryCard(type: .idea, body: "round trip")])
        let first = try ScwCodec.encode(original)
        let desktopLikeRoot = try jsonObject(first)
        let desktopLikeData = try JSONSerialization.data(withJSONObject: desktopLikeRoot)
        let reopened = try ScwCodec.decode(desktopLikeData)
        let second = try cards(jsonObject(ScwCodec.encode(reopened)))[0]
        try expect(second["type"] as? String == "相手" && second["text"] as? String == "round trip", "iPhone/Desktop/iPhone round trip")
    }
}

private extension Array {
    var single: Element? { count == 1 ? self[0] : nil }
}
