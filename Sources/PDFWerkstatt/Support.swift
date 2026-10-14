import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let pageCount: Int
    let byteCount: Int

    init?(url: URL) {
        guard let document = PDFDocument(url: url), !document.isLocked else { return nil }
        self.url = url
        self.pageCount = document.pageCount
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
        self.byteCount = size?.intValue ?? 0
    }

    var name: String { url.lastPathComponent }
    var baseName: String { url.deletingPathExtension().lastPathComponent }
}

/// Lädt Dateien und meldet, welche nicht lesbar waren.
func loadPDFFiles(_ urls: [URL]) -> (files: [PDFFile], failures: [String]) {
    var files: [PDFFile] = []
    var failures: [String] = []
    for url in urls where url.pathExtension.lowercased() == "pdf" {
        if let file = PDFFile(url: url) {
            files.append(file)
        } else {
            failures.append(url.lastPathComponent)
        }
    }
    return (files, failures)
}

func formatBytes(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}

@MainActor
enum FileDialogs {
    static func openPDFs(multiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func savePDF(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Hier speichern"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

enum StatusMessage: Equatable {
    case success(String, [URL])
    case failure(String)
}

struct StatusView: View {
    let status: StatusMessage?

    var body: some View {
        switch status {
        case .success(let text, let urls):
            HStack(spacing: 8) {
                Label(text, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if !urls.isEmpty {
                    Button("Im Finder zeigen") { FileDialogs.reveal(urls) }
                        .buttonStyle(.link)
                }
            }
        case .failure(let text):
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}

struct ToolHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DropHint: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40))
            Text(text)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

struct FileRow: View {
    let file: PDFFile

    var body: some View {
        HStack {
            Image(systemName: "doc.richtext").foregroundStyle(.red)
            Text(file.name).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text("\(file.pageCount) S. · \(formatBytes(file.byteCount))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
