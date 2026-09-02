import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let storyCardWriter = UTType(exportedAs: "com.example.storycardwriter.scw", conformingTo: .json)
}

enum StoryProjectFileDecoder {
    private struct Envelope: Decodable { let story: StoryProject }

    static func decode(_ data: Data) throws -> StoryProject {
        let decoder = JSONDecoder()
        if let project = try? decoder.decode(StoryProject.self, from: data) { return project }
        return try decoder.decode(Envelope.self, from: data).story
    }

    static func encode(_ project: StoryProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(project)
    }
}

struct StoryProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.storyCardWriter, .json] }
    var project: StoryProject

    init(project: StoryProject) { self.project = project }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        project = try StoryProjectFileDecoder.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try StoryProjectFileDecoder.encode(project))
    }
}

@MainActor
final class StoryStore: ObservableObject {
    @Published var project: StoryProject? {
        didSet { persist() }
    }

    private let key = "StoryCardWriter.activeProject.v2"

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            project = try? StoryProjectFileDecoder.decode(data)
        }
    }

    func start(_ project: StoryProject) { self.project = project }
    func close() { project = nil }

    private func persist() {
        guard let project, let data = try? StoryProjectFileDecoder.encode(project) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
