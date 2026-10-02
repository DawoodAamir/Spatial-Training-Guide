// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TrainingCore", platforms: [.macOS("27.0"), .visionOS("27.0")], products: [.library(name: "TrainingCore", targets: ["TrainingCore"])], targets: [.target(name: "TrainingCore", path: "Sources/Core"), .testTarget(name: "TrainingTests", dependencies: ["TrainingCore"], path: "Tests/Core")])
