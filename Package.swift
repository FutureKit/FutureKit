// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var targets = [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    Target.target(
        name: "FutureKit",
        dependencies: []),
]
#if !os(Linux)
targets += [
    .target(
        name: "BlockBasedTestCase",
        dependencies: []),
    .testTarget(
        name: "FutureKitTests",
        dependencies: ["FutureKit", "BlockBasedTestCase"]),
]
#endif


let package = Package(
    name: "FutureKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "FutureKit",
            targets: ["FutureKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: targets,
    swiftLanguageVersions: [3]
)
