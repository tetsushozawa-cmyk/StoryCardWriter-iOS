import PhotosUI
import SwiftUI

struct CharacterMemoView: View {
    @Binding var project: StoryProject
    let characterID: String

    @Environment(\.dismiss) private var dismiss
    @State private var character: CharacterData
    @State private var memoDraft = ""
    @State private var sectionTitle = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingSectionPrompt = false
    @State private var editingNote: NoteLocation?
    @State private var noteText = ""

    init(project: Binding<StoryProject>, characterID: String) {
        _project = project
        self.characterID = characterID
        _character = State(initialValue: project.wrappedValue.character(characterID))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(character.name).font(.title.bold())
                photoArea
                TextEditor(text: $memoDraft)
                    .frame(height: 90).padding(6)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if memoDraft.isEmpty { Text("自由メモ").foregroundStyle(.secondary).padding(12).allowsHitTesting(false) }
                    }
                HStack {
                    Button("メモを追加") { addNote(sectionID: nil, text: memoDraft); memoDraft = "" }
                        .buttonStyle(.borderedProminent).disabled(trimmed(memoDraft).isEmpty)
                    Button("項目枠を追加") { sectionTitle = ""; showingSectionPrompt = true }
                        .buttonStyle(.bordered)
                }
                noteList(character.notes, sectionID: nil)
                ForEach(character.sections) { section in sectionView(section) }
                Button("戻る") { dismiss() }.buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("人物メモ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        .onChange(of: character) { project.updateCharacter(character) }
        .onChange(of: selectedPhoto) { loadPhoto() }
        .alert("項目名", isPresented: $showingSectionPrompt) {
            TextField("例：性格、過去、秘密", text: $sectionTitle)
            Button("作成") {
                guard !trimmed(sectionTitle).isEmpty else { return }
                character.sections.append(CharacterSection(title: trimmed(sectionTitle)))
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert(editingNote?.noteID == nil ? "後に追加" : "メモを編集", isPresented: .init(
            get: { editingNote != nil }, set: { if !$0 { editingNote = nil } }
        )) {
            TextField("メモ", text: $noteText, axis: .vertical)
            Button(editingNote?.noteID == nil ? "追加" : "更新") { commitNoteDialog() }
            Button("キャンセル", role: .cancel) { editingNote = nil }
        }
    }

    private var photoArea: some View {
        VStack(spacing: 8) {
            if let encoded = character.photoBase64,
               let data = Data(base64Encoded: encoded),
               let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    .frame(maxWidth: .infinity).background(.gray.opacity(0.1))
            }
            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text(character.photoBase64 == nil ? "写真を選ぶ" : "写真を変更")
                }.buttonStyle(.bordered)
                if character.photoBase64 != nil {
                    Button("写真を削除", role: .destructive) { character.photoBase64 = nil }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func sectionView(_ section: CharacterSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title).font(.headline)
                Spacer()
                Button(role: .destructive) {
                    character.sections.removeAll { $0.id == section.id }
                } label: { Image(systemName: "trash") }
            }
            noteList(section.notes, sectionID: section.id)
            Button("この項目にメモを追加") {
                noteText = ""; editingNote = NoteLocation(sectionID: section.id)
            }.buttonStyle(.bordered).frame(maxWidth: .infinity)
        }
        .padding(12).background(.background).clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.secondary.opacity(0.35)).allowsHitTesting(false))
    }

    private func noteList(_ notes: [CharacterNote], sectionID: String?) -> some View {
        ForEach(notes) { note in
            VStack(alignment: .leading, spacing: 6) {
                Text(note.text).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Button("後に追加") { noteText = ""; editingNote = NoteLocation(sectionID: sectionID, afterID: note.id) }
                    Button("編集") { noteText = note.text; editingNote = NoteLocation(sectionID: sectionID, noteID: note.id) }
                    Button("削除", role: .destructive) { removeNote(note.id, sectionID: sectionID) }
                }.font(.caption).buttonStyle(.bordered)
            }
            .padding(10).background(.gray.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func notes(sectionID: String?) -> [CharacterNote] {
        guard let sectionID else { return character.notes }
        return character.sections.first(where: { $0.id == sectionID })?.notes ?? []
    }

    private func setNotes(_ notes: [CharacterNote], sectionID: String?) {
        guard let sectionID else { character.notes = notes; return }
        guard let index = character.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        character.sections[index].notes = notes
    }

    private func addNote(sectionID: String?, text: String, afterID: String? = nil) {
        let value = trimmed(text); guard !value.isEmpty else { return }
        var values = notes(sectionID: sectionID)
        let note = CharacterNote(text: value)
        if let afterID, let index = values.firstIndex(where: { $0.id == afterID }) {
            values.insert(note, at: index + 1)
        } else { values.append(note) }
        setNotes(values, sectionID: sectionID)
    }

    private func removeNote(_ id: String, sectionID: String?) {
        setNotes(notes(sectionID: sectionID).filter { $0.id != id }, sectionID: sectionID)
    }

    private func commitNoteDialog() {
        guard let location = editingNote, !trimmed(noteText).isEmpty else { return }
        if let noteID = location.noteID {
            var values = notes(sectionID: location.sectionID)
            if let index = values.firstIndex(where: { $0.id == noteID }) { values[index].text = trimmed(noteText) }
            setNotes(values, sectionID: location.sectionID)
        } else { addNote(sectionID: location.sectionID, text: noteText, afterID: location.afterID) }
        editingNote = nil
    }

    private func loadPhoto() {
        guard let selectedPhoto else { return }
        Task {
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.82) {
                await MainActor.run { character.photoBase64 = jpeg.base64EncodedString() }
            }
        }
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private struct NoteLocation {
    let sectionID: String?
    var afterID: String? = nil
    var noteID: String? = nil
}
