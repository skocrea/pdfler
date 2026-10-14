import AppKit
import Foundation
import ImageIO
import PDFKit
import Quartz
import UniformTypeIdentifiers

public enum CompressionMode: String, CaseIterable, Identifiable, Sendable {
    /// Text, Vektorgrafik und Links bleiben erhalten; nur eingebettete Bilder werden
    /// neu als JPEG kodiert und herunterskaliert.
    case preserveText
    /// Jede Seite wird als JPEG-Bild neu aufgebaut. Maximale Ersparnis bei Scans,
    /// aber Text ist danach nicht mehr markierbar.
    case rasterize

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .preserveText: return "Text erhalten"
        case .rasterize: return "Seiten als Bilder"
        }
    }
}

public struct CompressionSettings: Equatable, Sendable {
    public static let qualityRange: ClosedRange<Double> = 0.05...1.0
    public static let resolutionRange: ClosedRange<Double> = 50...300

    public var mode: CompressionMode
    /// JPEG-Qualität von 0.05 (klein) bis 1.0 (beste Qualität).
    public var imageQuality: Double {
        didSet { imageQuality = imageQuality.clamped(to: Self.qualityRange) }
    }
    /// Zielauflösung für Bilder in DPI.
    public var resolution: Double {
        didSet { resolution = resolution.clamped(to: Self.resolutionRange) }
    }

    public init(mode: CompressionMode, imageQuality: Double, resolution: Double) {
        self.mode = mode
        self.imageQuality = imageQuality.clamped(to: Self.qualityRange)
        self.resolution = resolution.clamped(to: Self.resolutionRange)
    }
}

public enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case light, balanced, strong, extreme

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light: return "Leicht"
        case .balanced: return "Mittel"
        case .strong: return "Stark"
        case .extreme: return "Extrem"
        }
    }

    public var settings: CompressionSettings {
        switch self {
        case .light: return CompressionSettings(mode: .preserveText, imageQuality: 0.8, resolution: 200)
        case .balanced: return CompressionSettings(mode: .preserveText, imageQuality: 0.6, resolution: 150)
        case .strong: return CompressionSettings(mode: .preserveText, imageQuality: 0.4, resolution: 100)
        case .extreme: return CompressionSettings(mode: .rasterize, imageQuality: 0.35, resolution: 96)
        }
    }
}

public struct CompressionResult: Equatable, Sendable {
    public let outputURL: URL
    public let originalBytes: Int
    public let compressedBytes: Int
    /// `true`, wenn die Komprimierung die Datei nicht verkleinert hätte und deshalb
    /// das Original übernommen wurde.
    public let keptOriginal: Bool

    public var savedFraction: Double {
        guard originalBytes > 0 else { return 0 }
        return 1 - Double(compressedBytes) / Double(originalBytes)
    }
}

public enum PDFCompressor {
    /// Komprimiert `input` nach `output`. Wird die Datei dabei nicht kleiner,
    /// wird das Original unverändert übernommen.
    public static func compress(
        input: URL,
        output: URL,
        settings: CompressionSettings
    ) throws -> CompressionResult {
        let document = try PDFOperations.open(input)
        let originalBytes = try PDFOperations.fileSize(of: input)
        let data = try compressedData(for: document, settings: settings)

        if data.count >= originalBytes {
            if input.standardizedFileURL != output.standardizedFileURL {
                let temporary = temporaryURL(next: output)
                do {
                    try FileManager.default.copyItem(at: input, to: temporary)
                } catch {
                    throw PDFlerError.writeFailed(output)
                }
                try PDFOperations.replace(output, with: temporary)
            }
            return CompressionResult(
                outputURL: output,
                originalBytes: originalBytes,
                compressedBytes: originalBytes,
                keptOriginal: true
            )
        }

        let temporary = temporaryURL(next: output)
        do {
            try data.write(to: temporary)
        } catch {
            throw PDFlerError.writeFailed(output)
        }
        try PDFOperations.replace(output, with: temporary)
        return CompressionResult(
            outputURL: output,
            originalBytes: originalBytes,
            compressedBytes: data.count,
            keptOriginal: false
        )
    }

    public static func compressedData(
        for document: PDFDocument,
        settings: CompressionSettings
    ) throws -> Data {
        switch settings.mode {
        case .preserveText: return try filtered(document, settings: settings)
        case .rasterize: return try rasterized(document, settings: settings)
        }
    }

    // MARK: - Text erhalten (Quartz-Filter)

    /// Baut einen Quartz-Filter nach dem Vorbild von macOS' „Reduce File Size“.
    static func filterProperties(for settings: CompressionSettings) -> [String: Any] {
        // Längste Seite eines A4-Blatts (11,7 Zoll) bei der Zielauflösung.
        let maxPixels = Int((settings.resolution * 11.7).rounded())
        return [
            "Name": "PDFler",
            "FilterType": 1,
            "Domains": ["Applications": true, "Printing": true],
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "Compression Quality": settings.imageQuality,
                        "ImageCompression": "ImageJPEGCompress",
                        "ImageScaleSettings": [
                            "ImageScaleFactor": min(1.0, settings.resolution / 300),
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": maxPixels,
                            "ImageSizeMin": 128,
                        ] as [String: Any],
                    ] as [String: Any],
                ],
            ],
        ]
    }

    private static func filtered(_ document: PDFDocument, settings: CompressionSettings) throws -> Data {
        let filter: QuartzFilter? = QuartzFilter(properties: filterProperties(for: settings))
        guard let filter else { throw PDFlerError.renderingFailed(page: 1) }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdfler-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: temporary) }

        let options: [PDFDocumentWriteOption: Any] = [PDFDocumentWriteOption(rawValue: "QuartzFilter"): filter]
        guard document.write(to: temporary, withOptions: options),
              let data = try? Data(contentsOf: temporary)
        else {
            throw PDFlerError.writeFailed(temporary)
        }
        return data
    }

    // MARK: - Seiten als Bilder

    private static func rasterized(_ document: PDFDocument, settings: CompressionSettings) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil)
        else {
            throw PDFlerError.renderingFailed(page: 1)
        }

        let scale = settings.resolution / 72
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let size = displaySize(of: page)
            let pixelWidth = max(1, Int((size.width * scale).rounded()))
            let pixelHeight = max(1, Int((size.height * scale).rounded()))

            guard let bitmap = render(page, pixelWidth: pixelWidth, pixelHeight: pixelHeight),
                  let jpeg = jpegImage(from: bitmap, quality: settings.imageQuality)
            else {
                throw PDFlerError.renderingFailed(page: index + 1)
            }

            var box = CGRect(origin: .zero, size: size)
            context.beginPage(mediaBox: &box)
            context.draw(jpeg, in: box)
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Sichtbare Seitengröße in Punkt, inklusive Seitendrehung.
    static func displaySize(of page: PDFPage) -> CGSize {
        let bounds = page.bounds(for: .cropBox).size
        let rotated = abs(page.rotation) % 180 == 90
        return rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds
    }

    private static func render(_ page: PDFPage, pixelWidth: Int, pixelHeight: Int) -> CGImage? {
        // thumbnail(of:for:) berücksichtigt Drehung und Beschnitt wie in der Anzeige.
        let thumbnail = page.thumbnail(of: CGSize(width: pixelWidth, height: pixelHeight), for: .cropBox)
        var proposed = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        guard let source = thumbnail.cgImage(forProposedRect: &proposed, context: nil, hints: nil),
              let context = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            return nil
        }
        // JPEG kennt keine Transparenz: auf weißen Hintergrund zeichnen.
        let rect = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(source, in: rect)
        return context.makeImage()
    }

    private static func jpegImage(from image: CGImage, quality: Double) -> CGImage? {
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encoded as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination),
              let provider = CGDataProvider(data: encoded as CFData)
        else {
            return nil
        }
        // Ein JPEG-basiertes CGImage wird von Quartz direkt (DCT) ins PDF übernommen.
        return CGImage(
            jpegDataProviderSource: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func temporaryURL(next url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).pdf")
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
