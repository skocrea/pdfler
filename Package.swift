// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PDFWerkstatt",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PDFWerkstatt", targets: ["PDFWerkstatt"]),
        .library(name: "PDFWerkstattCore", targets: ["PDFWerkstattCore"]),
    ],
    targets: [
        .target(name: "PDFWerkstattCore"),
        .executableTarget(name: "PDFWerkstatt", dependencies: ["PDFWerkstattCore"]),
        .testTarget(name: "PDFWerkstattCoreTests", dependencies: ["PDFWerkstattCore"]),
    ]
)
