import Foundation
import PDFKit

/// Grundlegende Seitenoperationen: Öffnen, Zusammenfügen, Seiten löschen, Speichern.
public enum PDFOperations {
    public static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw PDFlerError.cannotOpen(url)
        }
        guard !document.isLocked else {
            throw PDFlerError.locked(url)
        }
        return document
    }

    /// Fügt die Dateien in der angegebenen Reihenfolge zu einem neuen Dokument zusammen.
    public static func merge(_ urls: [URL]) throws -> PDFDocument {
        guard !urls.isEmpty else { throw PDFlerError.noInput }
        return merge(documents: try urls.map(open))
    }

    public static func merge(documents: [PDFDocument]) -> PDFDocument {
        let result = PDFDocument()
        for document in documents {
            for index in 0..<document.pageCount {
                // Eine PDFPage gehört immer genau einem Dokument, daher kopieren.
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                result.insert(page, at: result.pageCount)
            }
        }
        return result
    }

    /// Entfernt die Seiten mit den angegebenen (0-basierten) Indizes.
    public static func removePages(_ indices: IndexSet, from document: PDFDocument) throws {
        guard !indices.isEmpty else { return }
        if let invalid = indices.first(where: { $0 < 0 || $0 >= document.pageCount }) {
            throw PDFlerError.pageOutOfRange(page: invalid + 1, pageCount: document.pageCount)
        }
        guard indices.count < document.pageCount else {
            throw PDFlerError.wouldRemoveAllPages
        }
        for index in indices.reversed() {
            document.removePage(at: index)
        }
    }

    /// Schreibt erst in eine temporäre Datei und ersetzt dann das Ziel. So kann auch
    /// über die Quelldatei gespeichert werden, aus der PDFKit noch liest.
    public static func write(_ document: PDFDocument, to url: URL) throws {
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).pdf")
        guard document.write(to: temporary) else {
            try? FileManager.default.removeItem(at: temporary)
            throw PDFlerError.writeFailed(url)
        }
        try replace(url, with: temporary)
    }

    static func replace(_ destination: URL, with source: URL) throws {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: source)
            } else {
                try fileManager.moveItem(at: source, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: source)
            throw PDFlerError.writeFailed(destination)
        }
    }

    static func fileSize(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }
}
