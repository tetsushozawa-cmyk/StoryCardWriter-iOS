import SwiftUI
import UniformTypeIdentifiers

struct StartView: View {
    enum Step { case home, newStory }

    @ObservedObject var store: StoryStore
    @State private var step: Step = .home
    @State private var title = ""
    @State private var participantCount = 2
    @State private var protagonistName = "人物A"
    @State private var partner1Name = "人物B"
    @State private var partner2Name = "友人"
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 8)
                Text("StoryCardWriter").font(.largeTitle.bold())
                Text("思いついた瞬間を逃さず、一枚のカードとして残す")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text(step == .home ? "開始" : "新規作成").font(.title2.bold())
                    if step == .home { homeContent } else { newStoryContent }
                }
                .padding(18)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.storyCardWriter, .json, .data]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                store.start(try StoryProjectFileDecoder.decode(Data(contentsOf: url)))
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("ファイルを開けませんでした", isPresented: .init(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") {} } message: { Text(errorMessage ?? "") }
    }

    private var homeContent: some View {
        VStack(spacing: 24) {
            Button("新規作成") { step = .newStory }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .frame(maxWidth: .infinity)
            Button("ファイルを開く") { isImporting = true }
                .buttonStyle(.bordered).controlSize(.large)
                .frame(maxWidth: .infinity)
            if store.project != nil {
                Button("前回の作品を続ける") {}
                    .buttonStyle(.bordered).controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var newStoryContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("作品タイトル", text: $title, color: .secondary)
            Text("登場人物数").font(.caption).foregroundStyle(.secondary)
            HStack {
                ForEach([2, 3], id: \.self) { count in
                    Button("\(count)人") { participantCount = count }
                        .buttonStyle(.borderedProminent)
                        .tint(participantCount == count ? .blue : .gray.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            field("主人公名（任意）", text: $protagonistName, color: .blue)
            field(participantCount == 2 ? "相手役名（任意）" : "相手役1名（任意）", text: $partner1Name, color: .green)
            if participantCount == 3 {
                field("相手役2名（任意）", text: $partner2Name, color: .purple)
            }
            Button("執筆開始") {
                store.start(StoryProject(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    participantCount: participantCount,
                    protagonistName: normalized(protagonistName, "人物A"),
                    partner1Name: normalized(partner1Name, "人物B"),
                    partner2Name: normalized(partner2Name, "友人")
                ))
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("戻る") { step = .home }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
        }
    }

    private func field(_ label: String, text: Binding<String>, color: Color) -> some View {
        TextField(label, text: text)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.65)))
    }

    private func normalized(_ value: String, _ fallback: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? fallback : text
    }
}
