// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PDFler",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PDFler", targets: ["PDFler"]),
        .library(name: "PDFlerCore", targets: ["PDFlerCore"]),
    ],
    targets: [
        .target(name: "PDFlerCore"),
        .executableTarget(name: "PDFler", dependencies: ["PDFlerCore"]),
        .testTarget(name: "PDFlerCoreTests", dependencies: ["PDFlerCore"]),
    ]
)
