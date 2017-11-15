import PackageDescription

var targets = [
    Target(name: "FutureKit", dependencies: []),
]

#if !os(Linux)
    targets += [
        Target(name: "BlockBasedTestCase", dependencies: []),
        Target(name: "FutureKitTests", dependencies: ["FutureKit", "BlockBasedTestCase"]),
    ]
#endif

let package = Package(
    name: "FutureKit",
    targets: targets,
    dependencies: []
)
