import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoryStore()
    @State private var openFileError: String?

    var body: some View {
        NavigationStack {
            if store.project != nil {
                EditorView(project: Binding(
                    get: { store.project ?? StoryProject() },
                    set: { store.project = $0 }
                ), onClose: { store.close() })
            } else {
                StartView(store: store)
            }
        }
        .onOpenURL(perform: openFile)
        .alert("ファイルを開けませんでした", isPresented: .init(
            get: { openFileError != nil },
            set: { if !$0 { openFileError = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(openFileError ?? "")
        }
    }

    private func openFile(_ url: URL) {
        do {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            store.start(try StoryProjectFileDecoder.decode(Data(contentsOf: url)))
        } catch {
            openFileError = error.localizedDescription
        }
    }
}
