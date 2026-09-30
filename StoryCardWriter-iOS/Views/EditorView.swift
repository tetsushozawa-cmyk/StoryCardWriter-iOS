import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var project: StoryProject
    let onClose: () -> Void

    @State private var selectedType: CardType = .idea
    @State private var bodyText = ""
    @State private var editingID: String?
    @State private var insertAfterID: String?
    @State private var characterID: String?
    @State private var settingsExpanded = true
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var errorMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    Button(settingsExpanded ? "▲ 設定・人物メモ" : "▼ 設定・人物メモ") {
                        withAnimation { settingsExpanded.toggle() }
                    }
                    .font(.caption.bold()).foregroundStyle(.secondary)

                    if settingsExpanded { settings }

                    if project.cards.isEmpty {
                        Text("カードはまだありません")
                            .foregroundStyle(.secondary).padding(.vertical, 30)
                    }

                    ForEach(project.cards) { card in
                        StoryCardRow(
                            card: card,
                            label: project.cardLabel(for: card.type),
                            onInsert: { beginInsert(after: card) },
                            onEdit: { beginEdit(card) },
                            onDelete: { delete(card) }
                        )
                        .id(card.id)
                    }

                    editor.id("editor")
                }
                .padding(14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: project.cards.count) {
                guard let id = project.cards.last?.id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(project.title.isEmpty ? "無題の作品" : project.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $characterID) { id in
            NavigationStack {
                CharacterMemoView(project: $project, characterID: id)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.storyCardWriter, .json, .data]) { importFile($0) }
        .fileExporter(
            isPresented: $isExporting,
            document: StoryProjectDocument(project: project),
            contentType: .storyCardWriter,
            defaultFilename: safeFilename
        ) { result in if case .failure(let error) = result { errorMessage = error.localizedDescription } }
        .alert("操作を完了できませんでした", isPresented: .init(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        .onChange(of: scenePhase) {
            if scenePhase != .active { commitPendingInput() }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.title.isEmpty ? "無題の作品" : project.title).font(.title2.bold())
            HStack(spacing: 6) {
                characterButton("protagonist", project.protagonistName)
                characterButton("partner1", project.partner1Name)
                if project.participantCount == 3 { characterButton("partner2", project.partner2Name) }
            }
            Button("初期画面へ", role: .destructive, action: onClose)
                .buttonStyle(.bordered).frame(maxWidth: .infinity)
        }
        .padding(.bottom, 4)
    }

    private func characterButton(_ id: String, _ name: String) -> some View {
        Button("\(name) メモ") { characterID = id }
            .buttonStyle(.bordered).font(.caption).lineLimit(1).frame(maxWidth: .infinity)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if insertAfterID != nil { Text("このカードの後に追加").font(.caption.bold()) }
            HStack(spacing: 4) {
                Button(editingID == nil ? "追加" : "更新", action: commit)
                    .buttonStyle(.borderedProminent).disabled(trimmedBody.isEmpty)
                ForEach(project.availableTypes, id: \.self) { type in
                    Button(type.displayName) { selectedType = type }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedType == type ? type.color : type.color.opacity(0.25))
                        .font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            TextEditor(text: $bodyText)
                .focused($editorFocused)
                .frame(height: 120).padding(5)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)).allowsHitTesting(false))
            HStack {
                if editingID != nil || insertAfterID != nil {
                    Button("キャンセル", action: clearMode).buttonStyle(.bordered)
                }
                Button("保存", action: save).buttonStyle(.bordered)
                ShareLink(item: shareText, preview: SharePreview(project.title)) {
                    Text("共有")
                }.buttonStyle(.bordered)
                Button("保存ファイルを開く") { isImporting = true }.buttonStyle(.bordered)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .font(.caption)
            Button("初期画面へ", role: .destructive, action: onClose)
                .buttonStyle(.bordered).frame(maxWidth: .infinity)
        }
        .padding(10).background(.background).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var trimmedBody: String { bodyText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var safeFilename: String {
        let name = project.title.isEmpty ? "untitled" : project.title
        return name.replacingOccurrences(of: "/", with: "_") + ".scw"
    }
    private var shareText: String {
        guard let data = try? StoryProjectFileDecoder.encode(project),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private func beginInsert(after card: StoryCard) {
        editingID = nil; insertAfterID = card.id; selectedType = .idea
        bodyText = ""; editorFocused = true
    }

    private func beginEdit(_ card: StoryCard) {
        insertAfterID = nil; editingID = card.id; selectedType = card.type
        bodyText = card.body; editorFocused = true
    }

    private func delete(_ card: StoryCard) {
        project.cards.removeAll { $0.id == card.id }
        if editingID == card.id || insertAfterID == card.id { clearMode() }
    }

    private func commit() {
        guard !trimmedBody.isEmpty else { return }
        if let editingID, let index = project.cards.firstIndex(where: { $0.id == editingID }) {
            project.cards[index].type = selectedType
            project.cards[index].body = trimmedBody
        } else {
            let card = StoryCard(type: selectedType, body: trimmedBody)
            if let insertAfterID, let index = project.cards.firstIndex(where: { $0.id == insertAfterID }) {
                project.cards.insert(card, at: index + 1)
            } else { project.cards.append(card) }
        }
        clearMode(); editorFocused = true
    }

    private func save() {
        commitPendingInput()
        isExporting = true
    }

    private func commitPendingInput() {
        guard !trimmedBody.isEmpty else { return }
        commit()
    }

    private func clearMode() {
        editingID = nil; insertAfterID = nil; selectedType = .idea; bodyText = ""
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            project = try StoryProjectFileDecoder.decode(Data(contentsOf: url))
            clearMode()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct StoryCardRow: View {
    let card: StoryCard
    let label: String
    let onInsert: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            if card.type == .idea || card.type == .legacyPartner2 { Spacer(minLength: 38) }
            VStack(alignment: .leading, spacing: 8) {
                Text(label).font(.caption.bold()).foregroundStyle(card.type.color)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(card.type.color.opacity(0.12)).clipShape(Capsule())
                HStack {
                    Spacer()
                    Button("後に追加", action: onInsert)
                    Button("編集", action: onEdit)
                    Button("削除", role: .destructive, action: onDelete)
                }.font(.caption2).buttonStyle(.bordered)
                Text(card.body).font(.body).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12).background(card.type.color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(card.type.color.opacity(0.65)).allowsHitTesting(false))
            .frame(maxWidth: (card.type == .target || card.type == .reference) ? 300 : 350)
            if card.type == .subject || card.type == .legacyHero { Spacer(minLength: 38) }
        }
        .frame(maxWidth: .infinity)
    }
}

extension String: @retroactive Identifiable { public var id: String { self } }
