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
    swiftLanguageVersions: [.v4, .version("4.2"), .version("5.0")]
)
