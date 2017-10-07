// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "DNS",
    products: [
        .library(name: "DNS", targets: ["DNS"]),
    ],
    targets: [
        .target(name: "DNS", dependencies: []),
        .testTarget(name: "DNSTests", dependencies: ["DNS"])
    ],
    swiftLanguageVersions: [4]
)
