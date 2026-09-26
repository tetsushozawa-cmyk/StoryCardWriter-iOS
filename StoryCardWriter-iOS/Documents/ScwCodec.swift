import Foundation

enum ScwCodec {
    static func decode(_ data: Data) throws -> StoryProject {
        let decoder = JSONDecoder()
        let rootValue = try decoder.decode(JSONValue.self, from: data)
        guard let root = rootValue.objectValue else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let storyValue: JSONValue
        let wasWrapped: Bool
        if let wrappedStory = root["story"], wrappedStory.objectValue != nil {
            storyValue = wrappedStory
            wasWrapped = true
        } else {
            storyValue = rootValue
            wasWrapped = false
        }

        var project = try decoder.decode(
            StoryProject.self,
            from: JSONEncoder().encode(storyValue)
        )
        project.sourceRootJSON = root
        project.sourceWasWrapped = wasWrapped
        return project
    }

    static func encode(_ project: StoryProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(project)
    }
}
