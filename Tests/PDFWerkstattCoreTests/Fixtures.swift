import CoreGraphics
import Foundation
import PDFKit

/// Erzeugt Test-PDFs. Jede Seite wird über ihre Breite identifiziert.
enum Fixtures {
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFWerkstattTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    static func makePDF(
        at url: URL,
        pageWidths: [CGFloat],
        height: CGFloat = 400,
        noiseImage: Bool = false
    ) throws -> URL {
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let image = noiseImage ? makeNoiseImage(width: 1200, height: 1200) : nil
        for width in pageWidths {
            var box = CGRect(x: 0, y: 0, width: width, height: height)
            context.beginPage(mediaBox: &box)
            context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            context.fill(box.insetBy(dx: 20, dy: 20))
            if let image { context.draw(image, in: box) }
            context.endPage()
        }
        context.closePDF()
        return url
    }

    static func pageWidths(of document: PDFDocument) -> [CGFloat] {
        (0..<document.pageCount).compactMap { document.page(at: $0)?.bounds(for: .mediaBox).width }
    }

    /// Rauschen lässt sich verlustfrei kaum komprimieren – ideal, um JPEG-Ersparnis zu prüfen.
    static func makeNoiseImage(width: Int, height: Int) -> CGImage {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in bytes.indices where index % 4 != 3 {
            bytes[index] = UInt8.random(in: 0...255, using: &generator)
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
