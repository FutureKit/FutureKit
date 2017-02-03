import PackageDescription

let package = Package(
    name: "FutureKit",
    dependencies: [],
    exclude: [
      "docs",
      "FutureKit/FutureKit.h",
      "FutureKit/Utils/ObjectiveCExceptionHandler.h",
      "FutureKit/Utils/ObjectiveCExceptionHandler.m",
      "FutureKit iOS Testing AppTests",
      "FutureKit iOS Tests",
      "FutureKit OSX Tests",
      "FutureKit tvOS",
      "FutureKit tvOSTests",
      "FutureKit watchOS",
      "FutureKit.xcworkspace",
      "FutureKitTests"
    ]
)
