// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AiMCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "AiMCore", targets: ["AiMCore"])],
    targets: [
        .target(name: "AiMCore"),
        .testTarget(name: "AiMCoreTests", dependencies: ["AiMCore"])
    ]
)
