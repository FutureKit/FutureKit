import PackageDescription

let package = Package(
    name: "FutureKit",
    targets: [
        Target(name: "FutureKit", dependencies: []),
        Target(name: "BlockBasedTestCase", dependencies: []),
        Target(name: "FutureKitTests", dependencies: ["FutureKit", "BlockBasedTestCase"]),
    ],
    dependencies: []
)
