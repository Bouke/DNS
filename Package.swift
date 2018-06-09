// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "DNS",
    products: [
        .library(name: "DNS", targets: ["DNS"]),
        .executable(name: "dns-forwarder", targets: ["Server"])
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "1.0.8"),
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "DNS", dependencies: []),
        .target(name: "Server", dependencies: ["DNS", "Socket", "Utility"]),
        .testTarget(name: "DNSTests", dependencies: ["DNS"])
    ],
    swiftLanguageVersions: [4]
)
