// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "STARSDK",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .iOS(.v10),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "STARSDK",
            targets: ["STARSDK"]
        ),
        .library(
            name: "STARSDK_CALIBRATION",
            targets: ["STARSDK_CALIBRATION"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.12.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "STARSDK",
            dependencies: ["SQLite"]
        ),
        .target(
            name: "STARSDK_CALIBRATION",
            dependencies: ["SQLite"],
            swiftSettings: [.define("CALIBRATION")]
        ),
        .testTarget(
            name: "STARSDKTests",
            dependencies: ["STARSDK"]
        ),
    ]
)
