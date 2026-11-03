// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnhancedSkills",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "EnhancedSkills",
            targets: ["EnhancedSkills"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EnhancedSkills",
            path: "EnhancedSkills",
            exclude: [
                "EnhancedSkills.entitlements"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "EnhancedSkillsTests",
            dependencies: ["EnhancedSkills"],
            path: "EnhancedSkillsTests"
        )
    ]
)
