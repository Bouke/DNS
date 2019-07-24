// swift-tools-version:4.2

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
    swiftLanguageVersions: [.v4, .v4_2, .version("5")]
)
