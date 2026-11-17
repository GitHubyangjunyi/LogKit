// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogKit",
	platforms: [.iOS(.v15), .macOS(.v27), .visionOS(.v27), .watchOS(.v27), .tvOS(.v27),],
    products: [
        .library( name: "LogKit", targets: ["LogKit"]),
    ],
    targets: [
        .target(name: "LogKit"),
        .testTarget(name: "LogKitTests", dependencies: ["LogKit"]),
    ],
	swiftLanguageModes: [.v6]
)
