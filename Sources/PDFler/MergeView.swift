import PDFlerCore
import SwiftUI

struct MergeView: View {
    @State private var files: [PDFFile] = []
    @State private var selection = Set<PDFFile.ID>()
    @State private var status: StatusMessage?

    var body: some View {
        VStack(spacing: 12) {
            ToolHeader(
                title: "PDFs zusammenfügen",
                subtitle: "Dateien hinzufügen oder hineinziehen. Die Reihenfolge lässt sich per Drag & Drop ändern."
            )

            List(selection: $selection) {
                ForEach(files) { file in
                    FileRow(file: file)
                }
                .onMove { files.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { files.remove(atOffsets: $0) }
            }
            .overlay { if files.isEmpty { DropHint(text: "PDFs hierher ziehen") } }
            .dropDestination(for: URL.self) { urls, _ in
                add(urls)
                return true
            }

            HStack {
                Button("Hinzufügen …") { add(FileDialogs.openPDFs(multiple: true)) }
                Button("Entfernen") {
                    files.removeAll { selection.contains($0.id) }
                    selection.removeAll()
                }
                .disabled(selection.isEmpty)
                Button("Nach oben") { moveSelection(by: -1) }.disabled(selection.count != 1)
                Button("Nach unten") { moveSelection(by: 1) }.disabled(selection.count != 1)
                Spacer()
                Text("\(files.reduce(0) { $0 + $1.pageCount }) Seiten gesamt")
                    .foregroundStyle(.secondary)
                Button("Zusammenfügen …", action: merge)
                    .buttonStyle(.borderedProminent)
                    .disabled(files.count < 2)
                    .keyboardShortcut(.defaultAction)
            }

            StatusView(status: status)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private func add(_ urls: [URL]) {
        let loaded = loadPDFFiles(urls)
        files.append(contentsOf: loaded.files)
        status = loaded.failures.isEmpty
            ? nil
            : .failure("Nicht lesbar: \(loaded.failures.joined(separator: ", "))")
    }

    private func moveSelection(by offset: Int) {
        guard let id = selection.first,
              let index = files.firstIndex(where: { $0.id == id })
        else { return }
        let target = index + offset
        guard files.indices.contains(target) else { return }
        files.swapAt(index, target)
    }

    private func merge() {
        let suggested = "\(files.first?.baseName ?? "Dokument") zusammengefügt.pdf"
        guard let output = FileDialogs.savePDF(suggestedName: suggested) else { return }
        do {
            let document = try PDFOperations.merge(files.map(\.url))
            try PDFOperations.write(document, to: output)
            status = .success("\(document.pageCount) Seiten gespeichert: \(output.lastPathComponent)", [output])
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}
