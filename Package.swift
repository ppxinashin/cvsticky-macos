// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CVSticky",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "CVSticky", targets: ["CVSticky"])
    ],
    targets: [
        .executableTarget(
            name: "CVSticky",
            path: "Sources/CVSticky",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CVStickyTests", dependencies: ["CVSticky"])
    ]
)
