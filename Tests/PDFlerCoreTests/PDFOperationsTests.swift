import PDFKit
@testable import PDFlerCore
import XCTest

final class PDFOperationsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMergeKeepsOrderAndAllPages() throws {
        let first = try Fixtures.makePDF(at: directory.appendingPathComponent("a.pdf"), pageWidths: [201, 202])
        let second = try Fixtures.makePDF(at: directory.appendingPathComponent("b.pdf"), pageWidths: [301])
        let output = directory.appendingPathComponent("merged.pdf")

        let merged = try PDFOperations.merge([second, first])
        try PDFOperations.write(merged, to: output)

        let reopened = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(Fixtures.pageWidths(of: reopened), [301, 201, 202])
    }

    func testMergeWithoutInputThrows() {
        XCTAssertThrowsError(try PDFOperations.merge([])) { error in
            XCTAssertEqual(error as? PDFlerError, .noInput)
        }
    }

    func testMergeRejectsNonPDF() throws {
        let text = directory.appendingPathComponent("notes.pdf")
        try Data("kein PDF".utf8).write(to: text)
        XCTAssertThrowsError(try PDFOperations.merge([text])) { error in
            XCTAssertEqual(error as? PDFlerError, .cannotOpen(text))
        }
    }

    func testRemovePages() throws {
        let url = try Fixtures.makePDF(at: directory.appendingPathComponent("doc.pdf"), pageWidths: [201, 202, 203, 204, 205])
        let document = try PDFOperations.open(url)

        try PDFOperations.removePages(IndexSet([1, 3]), from: document)

        XCTAssertEqual(Fixtures.pageWidths(of: document), [201, 203, 205])
    }

    func testRemovingAllPagesThrows() throws {
        let url = try Fixtures.makePDF(at: directory.appendingPathComponent("doc.pdf"), pageWidths: [201, 202])
        let document = try PDFOperations.open(url)

        XCTAssertThrowsError(try PDFOperations.removePages(IndexSet([0, 1]), from: document)) { error in
            XCTAssertEqual(error as? PDFlerError, .wouldRemoveAllPages)
        }
        XCTAssertEqual(document.pageCount, 2)
    }

    func testRemovingUnknownPageThrows() throws {
        let url = try Fixtures.makePDF(at: directory.appendingPathComponent("doc.pdf"), pageWidths: [201, 202])
        let document = try PDFOperations.open(url)

        XCTAssertThrowsError(try PDFOperations.removePages(IndexSet([5]), from: document)) { error in
            XCTAssertEqual(error as? PDFlerError, .pageOutOfRange(page: 6, pageCount: 2))
        }
    }

    func testSavingOverSourceFile() throws {
        let url = try Fixtures.makePDF(at: directory.appendingPathComponent("doc.pdf"), pageWidths: [201, 202, 203])
        let document = try PDFOperations.open(url)

        try PDFOperations.removePages(IndexSet([0]), from: document)
        try PDFOperations.write(document, to: url)

        let reopened = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(Fixtures.pageWidths(of: reopened), [202, 203])
    }
}
