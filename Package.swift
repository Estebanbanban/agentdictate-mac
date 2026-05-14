// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgentDictate",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AgentDictate", targets: ["AgentDictate"])
    ],
    targets: [
        .executableTarget(
            name: "AgentDictate",
            path: "AgentDictate",
            exclude: ["Info.plist", "Assets.xcassets"]
        ),
        .testTarget(
            name: "AgentDictateTests",
            dependencies: ["AgentDictate"],
            path: "AgentDictateTests"
        )
    ]
)
