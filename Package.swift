// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EyeCare",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EyeCare", targets: ["EyeCare"])],
    targets: [
        .target(name: "EyeCareCore"),
        .executableTarget(name: "EyeCare", dependencies: ["EyeCareCore"]),
        .testTarget(name: "EyeCareCoreTests", dependencies: ["EyeCareCore"]),
    ],
    swiftLanguageModes: [.v5]
)
