import PDFKit
import PDFWerkstattCore
import SwiftUI

struct DeletePagesView: View {
    @State private var sourceURL: URL?
    @State private var document: PDFDocument?
    /// Erhöht sich bei jeder Änderung, damit Vorschaubilder neu geladen werden.
    @State private var revision = 0
    @State private var selected = Set<Int>()
    @State private var rangeText = ""
    @State private var deletedCount = 0
    @State private var status: StatusMessage?

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 16)]

    var body: some View {
        VStack(spacing: 12) {
            ToolHeader(
                title: "Seiten löschen",
                subtitle: "Seiten anklicken oder als Bereich eingeben (z. B. 1, 3-5, 8-), dann löschen und speichern."
            )

            HStack {
                Button("PDF öffnen …") {
                    if let url = FileDialogs.openPDFs(multiple: false).first { load(url) }
                }
                if let sourceURL {
                    Text(sourceURL.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Text("· \(document?.pageCount ?? 0) Seiten").foregroundStyle(.secondary)
                }
                Spacer()
                TextField("Seiten, z. B. 1, 3-5", text: $rangeText)
                    .frame(width: 180)
                    .onSubmit(selectRange)
                Button("Auswählen", action: selectRange)
                    .disabled(document == nil || rangeText.isEmpty)
            }

            ScrollView {
                if let document {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            PageThumbnail(
                                page: document.page(at: index),
                                number: index + 1,
                                isSelected: selected.contains(index),
                                reloadKey: revision
                            )
                            .onTapGesture { toggle(index) }
                        }
                    }
                    .padding(4)
                }
            }
            .overlay { if document == nil { DropHint(text: "PDF hierher ziehen") } }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return false }
                load(url)
                return true
            }

            HStack {
                Button("Auswahl aufheben") { selected.removeAll() }.disabled(selected.isEmpty)
                Button("Zurücksetzen") { if let sourceURL { load(sourceURL) } }.disabled(deletedCount == 0)
                Spacer()
                Button("\(selected.count) Seite(n) löschen", role: .destructive, action: deleteSelected)
                    .disabled(selected.isEmpty)
                Button("Speichern unter …", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(deletedCount == 0)
            }

            StatusView(status: status)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private func load(_ url: URL) {
        do {
            document = try PDFOperations.open(url)
            sourceURL = url
            selected.removeAll()
            deletedCount = 0
            revision += 1
            status = nil
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func toggle(_ index: Int) {
        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
    }

    private func selectRange() {
        guard let document else { return }
        do {
            selected = try PageRangeParser.parse(rangeText, pageCount: document.pageCount)
                .reduce(into: Set<Int>()) { $0.insert($1) }
            status = nil
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func deleteSelected() {
        guard let document else { return }
        do {
            try PDFOperations.removePages(IndexSet(selected), from: document)
            deletedCount += selected.count
            status = .success("\(selected.count) Seite(n) gelöscht – noch nicht gespeichert.", [])
            selected.removeAll()
            revision += 1
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func save() {
        guard let document, let sourceURL else { return }
        let suggested = "\(sourceURL.deletingPathExtension().lastPathComponent) bearbeitet.pdf"
        guard let output = FileDialogs.savePDF(suggestedName: suggested) else { return }
        do {
            try PDFOperations.write(document, to: output)
            status = .success("Gespeichert: \(output.lastPathComponent)", [output])
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}

struct PageThumbnail: View {
    let page: PDFPage?
    let number: Int
    let isSelected: Bool
    let reloadKey: Int

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(nsImage: image).resizable().scaledToFit()
                    } else {
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(height: 170)
                .shadow(radius: 1)
                .overlay {
                    if isSelected { Color.red.opacity(0.18) }
                }

                if isSelected {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .red)
                        .padding(4)
                }
            }
            Text("Seite \(number)").font(.caption).monospacedDigit()
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .task(id: "\(reloadKey)-\(number)") {
            image = page?.thumbnail(of: CGSize(width: 260, height: 340), for: .cropBox)
        }
    }
}
