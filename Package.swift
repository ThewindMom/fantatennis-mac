// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FantaTennisMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FantaTennisCore", targets: ["FantaTennisCore"]),
        .executable(name: "fantatennis-mac", targets: ["FantaTennisMac"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "FantaTennisCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .executableTarget(
            name: "FantaTennisCoreSelfTest",
            dependencies: ["FantaTennisCore"]
        ),
        .executableTarget(
            name: "FantaTennisMac",
            dependencies: ["FantaTennisCore"]
        ),
    ]
)
