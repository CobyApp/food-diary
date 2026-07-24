import ProjectDescription

let bundlePrefix = "com.coby.food"
let deploymentTargets: DeploymentTargets = .iOS("18.0")
// Apple Developer team for code signing (used by Xcode + Fastlane automatic signing).
let teamId = "3Y8YH8GWMM"

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
// @Reducer synthesizes a CasePathable conformance on Action that references
// CasePathsCore runtime symbols; link it explicitly for FeatureKit.
let casePaths: TargetDependency = .package(product: "CasePathsCore")

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
        // Internal modules are STATIC frameworks: the app and each test bundle
        // become the single link points that pull in the Point-Free package
        // products fully. Dynamic frameworks instead embed those static libs
        // and dead-strip unused symbols, starving downstream test bundles
        // (TestStore / CasePathsCore) at link time.
        // Each external package product is declared once, on the lowest module
        // that imports it, and propagates through the static-framework chain to
        // the app and test bundles. Declaring a product on multiple targets (or
        // re-declaring on test targets) links the TCA closure more than once and
        // produces duplicate symbols.
        target("Models", product: .staticFramework, sources: "Models",
               dependencies: []),
        // ClientKit is the single owner of every external package product, so
        // each is linked exactly once and propagates up the static chain to
        // FeatureKit, the app, and every test bundle (FeatureKit imports TCA
        // transitively). Splitting them across modules double-links the shared
        // TCA closure (Dependencies/IssueReporting/Clocks) → duplicate symbols.
        target("ClientKit", product: .staticFramework, sources: "ClientKit",
               dependencies: [.target(name: "Models"), tca, dependencies, depMacros, issueReporting, casePaths]),
        target("FeatureKit", product: .staticFramework, sources: "FeatureKit",
               dependencies: [.target(name: "ClientKit")]),
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
            dependencies: [.target(name: "FeatureKit")],
            settings: .settings(base: [
                "DEVELOPMENT_TEAM": .string(teamId),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
        testTarget("ModelsTests", sources: "ModelsTests",
                   dependencies: [.target(name: "Models")]),
        testTarget("ClientKitTests", sources: "ClientKitTests",
                   dependencies: [.target(name: "ClientKit")]),
        testTarget("FeatureKitTests", sources: "FeatureKitTests",
                   dependencies: [.target(name: "FeatureKit")]),
    ],
    schemes: [
        // Explicit app scheme — Tuist's autogenerated app scheme is not emitted
        // reliably across `tuist generate` runs, so pin a stable one that builds
        // and runs the app.
        .scheme(
            name: "FoodDiary",
            shared: true,
            buildAction: .buildAction(targets: ["FoodDiary"]),
            testAction: .targets(
                ["ModelsTests", "ClientKitTests", "FeatureKitTests"],
                configuration: "Debug"
            ),
            runAction: .runAction(configuration: "Debug")
        ),
    ]
)
