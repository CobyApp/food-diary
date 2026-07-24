import ProjectDescription

let bundlePrefix = "com.coby.food"
let deploymentTargets: DeploymentTargets = .iOS("18.0")

func target(
    _ name: String,
    product: Product,
    sources: String,
    dependencies: [TargetDependency],
    hasResources: Bool = false
) -> Target {
    .target(
        name: name,
        destinations: .iOS,
        product: product,
        bundleId: "\(bundlePrefix).\(name.lowercased())",
        deploymentTargets: deploymentTargets,
        sources: ["Sources/\(sources)/**"],
        resources: hasResources ? ["Sources/\(sources)/Resources/**"] : [],
        dependencies: dependencies
    )
}

func testTarget(_ name: String, sources: String, dependencies: [TargetDependency]) -> Target {
    .target(
        name: name,
        destinations: .iOS,
        product: .unitTests,
        bundleId: "\(bundlePrefix).\(name.lowercased())",
        deploymentTargets: deploymentTargets,
        sources: ["Tests/\(sources)/**"],
        resources: ["Tests/\(sources)/Resources/**"],
        dependencies: dependencies
    )
}

let tca: TargetDependency = .package(product: "ComposableArchitecture")
// @DependencyClient (used by the ClientKit clients) expands to code that
// references the DependenciesMacros runtime library, so it must be linked
// explicitly — it is only a transitive product of TCA otherwise.
let depMacros: TargetDependency = .package(product: "DependenciesMacros")
let issueReporting: TargetDependency = .package(product: "IssueReporting")
// TCA re-exports Dependencies at compile time only; DependencyKey / DependencyValues
// runtime witnesses must be linked explicitly under Tuist native package integration.
let dependencies: TargetDependency = .package(product: "Dependencies")

let project = Project(
    name: "FoodDiary",
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.17.0")
        ),
    ],
    settings: .settings(
        base: [:],
        configurations: [
            .debug(name: "Debug", xcconfig: "Configurations/Secrets.xcconfig"),
            .release(name: "Release", xcconfig: "Configurations/Secrets.xcconfig"),
        ]
    ),
    targets: [
        target("Models", product: .framework, sources: "Models",
               dependencies: [tca]),
        target("ClientKit", product: .framework, sources: "ClientKit",
               dependencies: [.target(name: "Models"), tca, dependencies, depMacros, issueReporting]),
        target("FeatureKit", product: .framework, sources: "FeatureKit",
               dependencies: [.target(name: "ClientKit"), tca, dependencies, issueReporting]),
        .target(
            name: "FoodDiary",
            destinations: .iOS,
            product: .app,
            bundleId: "com.coby.food.dairy",
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "NSPhotoLibraryUsageDescription": "음식 사진에서 음식만 추출해 다이어리에 담기 위해 사진 접근이 필요합니다.",
                "NSCameraUsageDescription": "밥 먹을 때 음식 사진을 찍어 다이어리에 담기 위해 카메라 접근이 필요합니다.",
                "NSLocationWhenInUseUsageDescription": "사진을 찍은 위치 근처의 식당을 추천하기 위해 위치 정보가 필요합니다.",
            ]),
            sources: ["Sources/FoodDiary/**"],
            dependencies: [.target(name: "FeatureKit")]
        ),
        testTarget("ModelsTests", sources: "ModelsTests",
                   dependencies: [.target(name: "Models")]),
        testTarget("ClientKitTests", sources: "ClientKitTests",
                   dependencies: [.target(name: "ClientKit")]),
        testTarget("FeatureKitTests", sources: "FeatureKitTests",
                   dependencies: [.target(name: "FeatureKit")]),
    ]
)
