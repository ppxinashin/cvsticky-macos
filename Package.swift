// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CVSticky",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CVSticky", targets: ["CVSticky"])
    ],
    targets: [
        .executableTarget(
            name: "CVSticky",
            path: "Sources/CVSticky"
        )
    ]
)
