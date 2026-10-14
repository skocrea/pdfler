import Foundation

/// Liest Seitenangaben wie „1, 3-5, 8-“ (1-basiert) und liefert 0-basierte Indizes.
///
/// - `3-5`: Seiten 3 bis 5
/// - `8-`: Seite 8 bis Dokumentende
/// - `-2`: Seite 1 bis 2
public enum PageRangeParser {
    public static func parse(_ text: String, pageCount: Int) throws -> IndexSet {
        var result = IndexSet()
        let normalized = text
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        for rawPart in normalized.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            if part.isEmpty { continue }

            let bounds = part
                .split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let lower: Int
            let upper: Int
            switch bounds.count {
            case 1:
                lower = try number(bounds[0], in: part)
                upper = lower
            case 2 where !(bounds[0].isEmpty && bounds[1].isEmpty):
                lower = bounds[0].isEmpty ? 1 : try number(bounds[0], in: part)
                upper = bounds[1].isEmpty ? pageCount : try number(bounds[1], in: part)
            default:
                throw PDFWerkstattError.invalidRange(part)
            }

            guard lower <= upper else { throw PDFWerkstattError.invalidRange(part) }
            guard lower >= 1 else {
                throw PDFWerkstattError.pageOutOfRange(page: lower, pageCount: pageCount)
            }
            guard upper <= pageCount else {
                throw PDFWerkstattError.pageOutOfRange(page: upper, pageCount: pageCount)
            }
            result.insert(integersIn: (lower - 1)..<upper)
        }
        return result
    }

    private static func number(_ text: String, in part: String) throws -> Int {
        guard let value = Int(text) else { throw PDFWerkstattError.invalidRange(part) }
        return value
    }
}
