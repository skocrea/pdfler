import Foundation

public enum PDFWerkstattError: LocalizedError, Equatable {
    case cannotOpen(URL)
    case locked(URL)
    case noInput
    case wouldRemoveAllPages
    case pageOutOfRange(page: Int, pageCount: Int)
    case invalidRange(String)
    case writeFailed(URL)
    case renderingFailed(page: Int)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let url):
            return "„\(url.lastPathComponent)“ konnte nicht als PDF geöffnet werden."
        case .locked(let url):
            return "„\(url.lastPathComponent)“ ist passwortgeschützt."
        case .noInput:
            return "Es wurden keine Dateien ausgewählt."
        case .wouldRemoveAllPages:
            return "Es können nicht alle Seiten gelöscht werden – mindestens eine Seite muss übrig bleiben."
        case .pageOutOfRange(let page, let pageCount):
            return "Seite \(page) existiert nicht (das Dokument hat \(pageCount) Seiten)."
        case .invalidRange(let text):
            return "„\(text)“ ist keine gültige Seitenangabe. Beispiel: 1, 3-5, 8-"
        case .writeFailed(let url):
            return "„\(url.lastPathComponent)“ konnte nicht gespeichert werden."
        case .renderingFailed(let page):
            return "Seite \(page) konnte nicht verarbeitet werden."
        }
    }
}
