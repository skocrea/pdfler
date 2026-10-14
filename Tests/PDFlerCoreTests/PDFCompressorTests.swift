import PDFKit
@testable import PDFlerCore
import XCTest

final class PDFCompressorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRasterizeShrinksImageHeavyPDF() throws {
        let input = try Fixtures.makePDF(
            at: directory.appendingPathComponent("scan.pdf"), pageWidths: [595, 596], height: 842, noiseImage: true
        )
        let output = directory.appendingPathComponent("scan-small.pdf")

        let result = try PDFCompressor.compress(
            input: input,
            output: output,
            settings: CompressionSettings(mode: .rasterize, imageQuality: 0.3, resolution: 72)
        )

        XCTAssertFalse(result.keptOriginal)
        XCTAssertLessThan(result.compressedBytes, result.originalBytes)
        let compressed = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(Fixtures.pageWidths(of: compressed), [595, 596])
        XCTAssertEqual(compressed.page(at: 0)?.bounds(for: .mediaBox).height, 842)
    }

    func testPreserveTextShrinksImageHeavyPDF() throws {
        let input = try Fixtures.makePDF(
            at: directory.appendingPathComponent("photo.pdf"), pageWidths: [595, 596], height: 842, noiseImage: true
        )
        let output = directory.appendingPathComponent("photo-small.pdf")

        let result = try PDFCompressor.compress(input: input, output: output, settings: CompressionPreset.strong.settings)

        XCTAssertFalse(result.keptOriginal, "Der Quartz-Filter sollte Bilder neu kodieren")
        XCTAssertLessThan(result.compressedBytes, result.originalBytes)
        let compressed = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(Fixtures.pageWidths(of: compressed), [595, 596])
    }

    func testStrongerSettingsProduceSmallerFiles() throws {
        let input = try Fixtures.makePDF(
            at: directory.appendingPathComponent("scan.pdf"), pageWidths: [595], height: 842, noiseImage: true
        )
        let document = try PDFOperations.open(input)

        let mild = try PDFCompressor.compressedData(
            for: document, settings: CompressionSettings(mode: .rasterize, imageQuality: 0.9, resolution: 200)
        )
        let strong = try PDFCompressor.compressedData(
            for: document, settings: CompressionSettings(mode: .rasterize, imageQuality: 0.2, resolution: 72)
        )

        XCTAssertLessThan(strong.count, mild.count)
    }

    func testKeepsOriginalWhenCompressionWouldGrowFile() throws {
        let input = try Fixtures.makePDF(at: directory.appendingPathComponent("vector.pdf"), pageWidths: [201])
        let output = directory.appendingPathComponent("vector-out.pdf")

        let result = try PDFCompressor.compress(
            input: input,
            output: output,
            settings: CompressionSettings(mode: .rasterize, imageQuality: 1.0, resolution: 300)
        )

        XCTAssertTrue(result.keptOriginal)
        XCTAssertEqual(try Data(contentsOf: output), try Data(contentsOf: input))
    }

    func testSettingsAreClamped() {
        var settings = CompressionSettings(mode: .preserveText, imageQuality: 7, resolution: 10)
        XCTAssertEqual(settings.imageQuality, 1.0)
        XCTAssertEqual(settings.resolution, 50)

        settings.imageQuality = -1
        settings.resolution = 1000
        XCTAssertEqual(settings.imageQuality, 0.05)
        XCTAssertEqual(settings.resolution, 300)
    }
}
