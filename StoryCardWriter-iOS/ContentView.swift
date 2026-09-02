import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoryStore()

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
    }
}
