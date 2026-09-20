// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FindSFSymbols",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "FindSFSymbols",
            dependencies: ["SymbolSearch"],
            path: "Sources/FindSFSymbols",
            resources: [
                .process("Resources"),
            ]),
        .target(
            name: "SymbolSearch",
            path: "Sources/SymbolSearch"),
        .testTarget(
            name: "SymbolSearchTests",
            dependencies: ["SymbolSearch"],
            path: "Tests/SymbolSearchTests"),
        .testTarget(
            name: "FindSFSymbolsTests",
            dependencies: ["FindSFSymbols"],
            path: "Tests/FindSFSymbolsTests"),
    ]
)
