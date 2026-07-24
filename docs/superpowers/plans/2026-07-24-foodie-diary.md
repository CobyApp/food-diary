# Foodie Diary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS "foodie diary" that extracts food cutouts from meal photos (on-device Vision), tags them with a GPS-suggested restaurant, and collects them on a sticker-book home wall.

**Architecture:** Tuist-generated modular app. `App → FeatureKit → ClientKit → Models`. TCA drives all features; SwiftData (behind a `ModelActor` client returning `Sendable` DTOs) persists meals/cutouts; cutout PNGs live on disk. All I/O is a `@DependencyClient` so reducers are tested with `TestStore` + mock clients.

**Tech Stack:** Tuist 4, The Composable Architecture 1.x, SwiftUI, SwiftData, Vision, ImageIO/CoreLocation, Fastlane, Swift 6.

## Global Constraints

- Bundle ID: `com.coby.food.dairy`
- Minimum deployment target: **iOS 18.0**
- Swift 6 language mode; strict concurrency. Never pass SwiftData `@Model` objects across actor boundaries — clients return `Sendable` value DTOs.
- Source comments in English only (repo policy). User-facing strings may be Korean.
- Original source photos are NOT persisted — only extracted cutout PNGs under `Documents/cutouts/`.
- Google Places is interface-only in v1: `PlaceSearchClient.liveValue` returns deterministic mock data; the real key is read from a git-ignored `Secrets.xcconfig` later.
- No `.xcodeproj`/`.xcworkspace` committed (Tuist-generated, git-ignored).
- Commit messages: conventional commits, English, end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Phase 0 — Tooling & Scaffold

### Task 1: Tuist project scaffold with 4 modules + TCA

**Files:**
- Create: `Tuist.swift`
- Create: `Project.swift`
- Create: `Configurations/Secrets.example.xcconfig`
- Create: `Configurations/Secrets.xcconfig` (git-ignored, dev placeholder)
- Create: `Sources/Models/ModelsPlaceholder.swift`
- Create: `Sources/ClientKit/ClientKitPlaceholder.swift`
- Create: `Sources/FeatureKit/FeatureKitPlaceholder.swift`
- Create: `Sources/FoodDiary/FoodDiaryApp.swift`
- Create: `Tests/ModelsTests/SmokeTests.swift`
- Create: `Tests/ClientKitTests/SmokeTests.swift`
- Create: `Tests/FeatureKitTests/SmokeTests.swift`

**Interfaces:**
- Produces: four targets `Models`, `ClientKit`, `FeatureKit`, `FoodDiary` and test targets `ModelsTests`, `ClientKitTests`, `FeatureKitTests`. External SPM product `ComposableArchitecture` available to `FeatureKit`, `ClientKit`, and their tests.

- [ ] **Step 1: (removed) — external dependencies use native Xcode package integration**

> **DEVIATION (2026-07-24):** The original plan declared TCA via `Tuist/Package.swift` + `tuist install` (Tuist's SwiftPM integration). Under this machine's toolchain (Xcode 26.6 / Swift 6.3.3), Tuist's per-package `.xcodeproj` generation fails to wire TCA's transitive **macro** plugins (`CasePathsMacrosSupport`, etc.), giving `header '…-Swift.h' not found` at build. Fix: declare the package with `packages:` in `Project.swift` and depend via `.package(product: "ComposableArchitecture")`, which delegates macro resolution to Xcode's native SwiftPM. No `Tuist/Package.swift` and no `tuist install` step. (A benign warning remains: "ComposableArchitecture … static product linked from multiple targets" — verified not to cause duplicate-symbol errors; build and tests pass.)

- [ ] **Step 2: Write `Tuist.swift`**

```swift
import ProjectDescription

let tuist = Tuist(
    project: .tuist(compatibleXcodeVersions: .all)
)
```

- [ ] **Step 3: Write `Configurations/Secrets.example.xcconfig` and `Configurations/Secrets.xcconfig`**

`Secrets.example.xcconfig`:
```
// Copy to Secrets.xcconfig and fill in. Secrets.xcconfig is git-ignored.
GOOGLE_PLACES_API_KEY = 
```
`Secrets.xcconfig` (identical body; dev leaves it blank — PlaceSearchClient uses mock data regardless):
```
GOOGLE_PLACES_API_KEY = 
```

- [ ] **Step 4: Write `Project.swift`**

```swift
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
               dependencies: [.target(name: "Models"), tca]),
        target("FeatureKit", product: .framework, sources: "FeatureKit",
               dependencies: [.target(name: "ClientKit"), tca]),
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
```

- [ ] **Step 5: Write placeholder sources so every target compiles**

`Sources/Models/ModelsPlaceholder.swift`:
```swift
// Placeholder so the Models target has at least one source file.
enum ModelsPlaceholder {}
```
`Sources/ClientKit/ClientKitPlaceholder.swift`:
```swift
enum ClientKitPlaceholder {}
```
`Sources/FeatureKit/FeatureKitPlaceholder.swift`:
```swift
enum FeatureKitPlaceholder {}
```
`Sources/FoodDiary/FoodDiaryApp.swift`:
```swift
import SwiftUI

@main
struct FoodDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Foodie Diary")
        }
    }
}
```

- [ ] **Step 6: Write smoke tests for each test target**

`Tests/ModelsTests/SmokeTests.swift`:
```swift
import XCTest

final class SmokeTests: XCTestCase {
    func test_smoke() { XCTAssertTrue(true) }
}
```
`Tests/ClientKitTests/SmokeTests.swift` and `Tests/FeatureKitTests/SmokeTests.swift`: identical body (class `SmokeTests`, one `test_smoke` asserting true). Also create empty `Tests/ModelsTests/Resources/.gitkeep`, `Tests/ClientKitTests/Resources/.gitkeep`, `Tests/FeatureKitTests/Resources/.gitkeep` so the `resources` glob resolves.

- [ ] **Step 7: Generate & build**

Run: `cd /Users/doyoung_kim/Documents/Git/food-dairy && tuist generate --no-open && tuist build FoodDiary`
Expected: `Build Succeeded`. (No `tuist install` — native package integration resolves via xcodebuild during `tuist generate`. `tuist build` prints a deprecation notice favoring `tuist xcodebuild`; still functional.)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: tuist scaffold with Models/ClientKit/FeatureKit/App modules + TCA

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Fastlane lanes (test / build / beta)

**Files:**
- Create: `fastlane/Fastfile`
- Create: `fastlane/Appfile`
- Create: `Gemfile`

**Interfaces:**
- Produces: `fastlane test`, `fastlane build`, `fastlane beta` lanes.

- [ ] **Step 1: Write `Gemfile`**

```ruby
source "https://rubygems.org"
gem "fastlane"
```

- [ ] **Step 2: Write `fastlane/Appfile`**

```ruby
app_identifier("com.coby.food.dairy")
```

- [ ] **Step 3: Write `fastlane/Fastfile`**

```ruby
default_platform(:ios)

platform :ios do
  desc "Generate project, then run all unit tests"
  lane :test do
    sh("cd .. && tuist generate --no-open")
    run_tests(scheme: "FoodDiary")
  end

  desc "Generate project and build the app"
  lane :build do
    sh("cd .. && tuist generate --no-open")
    build_app(scheme: "FoodDiary", skip_archive: true, destination: "generic/platform=iOS Simulator")
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    sh("cd .. && tuist generate --no-open")
    build_app(scheme: "FoodDiary")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

- [ ] **Step 4: Verify Fastfile parses**

Run: `cd /Users/doyoung_kim/Documents/Git/food-dairy && fastlane lanes 2>/dev/null || echo "fastlane not installed — run: brew install fastlane"`
Expected: either the lane list, or the install hint (acceptable — lanes are scaffolded regardless).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: fastlane test/build/beta lanes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 1 — Models

### Task 3: Domain value types (`Coordinate`, `PlaceInfo`)

**Files:**
- Create: `Sources/Models/Coordinate.swift`
- Create: `Sources/Models/PlaceInfo.swift`
- Test: `Tests/ModelsTests/PlaceInfoTests.swift`
- Delete: `Sources/Models/ModelsPlaceholder.swift`

**Interfaces:**
- Produces:
  - `struct Coordinate: Codable, Hashable, Sendable { var latitude: Double; var longitude: Double }`
  - `struct PlaceInfo: Codable, Hashable, Sendable, Identifiable { var id: String; var name: String; var address: String; var coordinate: Coordinate?; var googlePlaceId: String? }`

- [ ] **Step 1: Write the failing test**

`Tests/ModelsTests/PlaceInfoTests.swift`:
```swift
import XCTest
@testable import Models

final class PlaceInfoTests: XCTestCase {
    func test_placeInfo_roundTripsThroughJSON() throws {
        let place = PlaceInfo(
            id: "abc",
            name: "라멘집",
            address: "후쿠오카 1-2-3",
            coordinate: Coordinate(latitude: 33.59, longitude: 130.40),
            googlePlaceId: "gp_1"
        )
        let data = try JSONEncoder().encode(place)
        let decoded = try JSONDecoder().decode(PlaceInfo.self, from: data)
        XCTAssertEqual(decoded, place)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ModelsTests`
Expected: FAIL — `cannot find 'PlaceInfo' in scope`.

- [ ] **Step 3: Write the implementation, delete placeholder**

`Sources/Models/Coordinate.swift`:
```swift
public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
```
`Sources/Models/PlaceInfo.swift`:
```swift
public struct PlaceInfo: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var address: String
    public var coordinate: Coordinate?
    public var googlePlaceId: String?

    public init(
        id: String,
        name: String,
        address: String,
        coordinate: Coordinate? = nil,
        googlePlaceId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.googlePlaceId = googlePlaceId
    }
}
```
Then delete `Sources/Models/ModelsPlaceholder.swift`.

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ModelsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(models): Coordinate and PlaceInfo value types

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: SwiftData models + DTOs (`Meal`, `FoodCutout`, snapshots)

**Files:**
- Create: `Sources/Models/Meal.swift`
- Create: `Sources/Models/FoodCutout.swift`
- Create: `Sources/Models/Snapshots.swift`
- Test: `Tests/ModelsTests/MealModelTests.swift`

**Interfaces:**
- Produces:
  - `@Model final class Meal { var id: UUID; var eatenAt: Date; var placeData: Data?; var memo: String; var rating: Int?; @Relationship(deleteRule: .cascade, inverse: \FoodCutout.meal) var cutouts: [FoodCutout] }` with computed `var place: PlaceInfo?` (encode/decode `placeData`).
  - `@Model final class FoodCutout { var id: UUID; var fileName: String; var createdAt: Date; var label: String?; var meal: Meal? }`
  - `struct MealSnapshot: Sendable, Identifiable, Equatable { let id: UUID; let eatenAt: Date; let place: PlaceInfo?; let memo: String; let rating: Int?; let cutouts: [CutoutSnapshot] }`
  - `struct CutoutSnapshot: Sendable, Identifiable, Equatable { let id: UUID; let fileName: String; let createdAt: Date; let label: String? }`
  - `Meal.snapshot() -> MealSnapshot`, `FoodCutout.snapshot() -> CutoutSnapshot`

- [ ] **Step 1: Write the failing test**

`Tests/ModelsTests/MealModelTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Models

final class MealModelTests: XCTestCase {
    @MainActor
    func test_meal_persistsAndSnapshots() throws {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let meal = Meal(eatenAt: Date(timeIntervalSince1970: 1_000_000), memo: "맛있었다", rating: 4)
        meal.place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")
        let cutout = FoodCutout(fileName: "a.png", label: "라멘")
        cutout.meal = meal
        meal.cutouts.append(cutout)
        context.insert(meal)
        try context.save()

        let snap = meal.snapshot()
        XCTAssertEqual(snap.memo, "맛있었다")
        XCTAssertEqual(snap.rating, 4)
        XCTAssertEqual(snap.place?.name, "라멘집")
        XCTAssertEqual(snap.cutouts.map(\.fileName), ["a.png"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ModelsTests`
Expected: FAIL — `cannot find 'Meal' in scope`.

- [ ] **Step 3: Write `Sources/Models/FoodCutout.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class FoodCutout {
    public var id: UUID
    public var fileName: String
    public var createdAt: Date
    public var label: String?
    public var meal: Meal?

    public init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = Date(),
        label: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.label = label
    }

    public func snapshot() -> CutoutSnapshot {
        CutoutSnapshot(id: id, fileName: fileName, createdAt: createdAt, label: label)
    }
}
```

- [ ] **Step 4: Write `Sources/Models/Meal.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class Meal {
    public var id: UUID
    public var eatenAt: Date
    public var placeData: Data?
    public var memo: String
    public var rating: Int?
    @Relationship(deleteRule: .cascade, inverse: \FoodCutout.meal)
    public var cutouts: [FoodCutout]

    public init(
        id: UUID = UUID(),
        eatenAt: Date = Date(),
        memo: String = "",
        rating: Int? = nil
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.memo = memo
        self.rating = rating
        self.cutouts = []
    }

    // PlaceInfo is stored as encoded JSON so it stays a plain value type.
    public var place: PlaceInfo? {
        get { placeData.flatMap { try? JSONDecoder().decode(PlaceInfo.self, from: $0) } }
        set { placeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    public func snapshot() -> MealSnapshot {
        MealSnapshot(
            id: id,
            eatenAt: eatenAt,
            place: place,
            memo: memo,
            rating: rating,
            cutouts: cutouts
                .sorted { $0.createdAt < $1.createdAt }
                .map { $0.snapshot() }
        )
    }
}
```

- [ ] **Step 5: Write `Sources/Models/Snapshots.swift`**

```swift
import Foundation

public struct CutoutSnapshot: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let fileName: String
    public let createdAt: Date
    public let label: String?

    public init(id: UUID, fileName: String, createdAt: Date, label: String?) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.label = label
    }
}

public struct MealSnapshot: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let eatenAt: Date
    public let place: PlaceInfo?
    public let memo: String
    public let rating: Int?
    public let cutouts: [CutoutSnapshot]

    public init(
        id: UUID,
        eatenAt: Date,
        place: PlaceInfo?,
        memo: String,
        rating: Int?,
        cutouts: [CutoutSnapshot]
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.place = place
        self.memo = memo
        self.rating = rating
        self.cutouts = cutouts
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `tuist test ModelsTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(models): SwiftData Meal/FoodCutout + Sendable snapshots

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 2 — Clients (ClientKit)

### Task 5: `ImageStore` (disk PNG storage helper)

**Files:**
- Create: `Sources/ClientKit/ImageStore.swift`
- Test: `Tests/ClientKitTests/ImageStoreTests.swift`
- Delete: `Sources/ClientKit/ClientKitPlaceholder.swift`

**Interfaces:**
- Produces:
  - `struct ImageStore: Sendable { var save: @Sendable (Data) throws -> String; var load: @Sendable (String) -> Data?; var delete: @Sendable (String) throws -> Void }`
  - `extension ImageStore { static func disk(directory: URL) -> ImageStore }`
  - `enum ImageStoreError: Error { case writeFailed }`

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/ImageStoreTests.swift`:
```swift
import XCTest
@testable import ClientKit

final class ImageStoreTests: XCTestCase {
    func test_save_thenLoad_returnsSameBytes() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ImageStore.disk(directory: dir)
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])

        let name = try store.save(bytes)
        XCTAssertEqual(store.load(name), bytes)

        try store.delete(name)
        XCTAssertNil(store.load(name))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ClientKitTests`
Expected: FAIL — `cannot find 'ImageStore' in scope`.

- [ ] **Step 3: Write the implementation, delete placeholder**

`Sources/ClientKit/ImageStore.swift`:
```swift
import Foundation

public enum ImageStoreError: Error { case writeFailed }

public struct ImageStore: Sendable {
    public var save: @Sendable (Data) throws -> String
    public var load: @Sendable (String) -> Data?
    public var delete: @Sendable (String) throws -> Void

    public init(
        save: @escaping @Sendable (Data) throws -> String,
        load: @escaping @Sendable (String) -> Data?,
        delete: @escaping @Sendable (String) throws -> Void
    ) {
        self.save = save
        self.load = load
        self.delete = delete
    }
}

public extension ImageStore {
    static func disk(directory: URL) -> ImageStore {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        return ImageStore(
            save: { data in
                let name = "\(UUID().uuidString).png"
                let url = directory.appendingPathComponent(name)
                do { try data.write(to: url) } catch { throw ImageStoreError.writeFailed }
                return name
            },
            load: { name in
                try? Data(contentsOf: directory.appendingPathComponent(name))
            },
            delete: { name in
                let url = directory.appendingPathComponent(name)
                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
            }
        )
    }

    static var cutoutsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cutouts", isDirectory: true)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ClientKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(clientkit): disk-backed ImageStore for cutout PNGs

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: `FoodCutoutClient` (Vision, on-device)

**Files:**
- Create: `Sources/ClientKit/FoodCutoutClient.swift`
- Test: `Tests/ClientKitTests/FoodCutoutClientTests.swift`
- Create: `Tests/ClientKitTests/Resources/test-food.jpg` (a real photo of a plated dish; add any JPEG with a clear food subject)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `struct Cutout: Equatable, Sendable { public var pngData: Data }`
  - `@DependencyClient struct FoodCutoutClient: Sendable { var extract: @Sendable (Data) async throws -> [Cutout] }`
  - `extension FoodCutoutClient: DependencyKey { static let liveValue: FoodCutoutClient }` and `testValue`, `previewValue`.
  - `DependencyValues.foodCutout` accessor.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/FoodCutoutClientTests.swift`:
```swift
import XCTest
import Dependencies
@testable import ClientKit

final class FoodCutoutClientTests: XCTestCase {
    func test_liveValue_extractsAtLeastOneCutout_fromFoodPhoto() async throws {
        let url = Bundle.module.url(forResource: "test-food", withExtension: "jpg")
        let data = try Data(contentsOf: XCTUnwrap(url))

        let client = FoodCutoutClient.liveValue
        let cutouts = try await client.extract(data)

        XCTAssertGreaterThanOrEqual(cutouts.count, 1)
        XCTAssertFalse(cutouts[0].pngData.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ClientKitTests`
Expected: FAIL — `cannot find 'FoodCutoutClient' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/ClientKit/FoodCutoutClient.swift`:
```swift
import Foundation
import Vision
import CoreImage
import Dependencies
import DependenciesMacros

public struct Cutout: Equatable, Sendable {
    public var pngData: Data
    public init(pngData: Data) { self.pngData = pngData }
}

@DependencyClient
public struct FoodCutoutClient: Sendable {
    public var extract: @Sendable (_ imageData: Data) async throws -> [Cutout]
}

extension FoodCutoutClient: DependencyKey {
    public static let liveValue = FoodCutoutClient(
        extract: { imageData in
            guard let ciImage = CIImage(data: imageData) else { return [] }
            let handler = VNImageRequestHandler(ciImage: ciImage)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            guard let result = request.results?.first else { return [] }

            let context = CIContext()
            var cutouts: [Cutout] = []
            for instance in result.allInstances {
                let buffer = try result.generateMaskedImage(
                    ofInstances: [instance],
                    from: handler,
                    croppedToInstancesExtent: true
                )
                let masked = CIImage(cvPixelBuffer: buffer)
                guard let cg = context.createCGImage(masked, from: masked.extent) else { continue }
                if let png = Self.pngData(from: cg) {
                    cutouts.append(Cutout(pngData: png))
                }
            }
            return cutouts
        }
    )

    // Encode a CGImage (with alpha) to PNG data without UIKit.
    private static func pngData(from cgImage: CGImage) -> Data? {
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        return context.pngRepresentation(
            of: ciImage,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }
}

extension FoodCutoutClient: TestDependencyKey {
    public static let testValue = FoodCutoutClient()
    public static let previewValue = FoodCutoutClient(
        extract: { _ in [Cutout(pngData: Data([0x89, 0x50, 0x4E, 0x47]))] }
    )
}

public extension DependencyValues {
    var foodCutout: FoodCutoutClient {
        get { self[FoodCutoutClient.self] }
        set { self[FoodCutoutClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ClientKitTests`
Expected: PASS (Vision runs on the simulator; the bundled food photo yields ≥1 cutout). If the chosen photo yields 0 instances, replace `test-food.jpg` with a clearer single-dish photo.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(clientkit): FoodCutoutClient using Vision foreground instance mask

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: `PhotoLocationClient` (EXIF GPS)

**Files:**
- Create: `Sources/ClientKit/PhotoLocationClient.swift`
- Test: `Tests/ClientKitTests/PhotoLocationClientTests.swift`
- Create: `Tests/ClientKitTests/Resources/gps-tagged.jpg` (a JPEG containing GPS EXIF; see step note)

**Interfaces:**
- Consumes: `Coordinate` from `Models`.
- Produces:
  - `@DependencyClient struct PhotoLocationClient: Sendable { var coordinate: @Sendable (Data) -> Coordinate? }`
  - `DependencyKey`/`TestDependencyKey` conformance, `DependencyValues.photoLocation`.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/PhotoLocationClientTests.swift`:
```swift
import XCTest
import Models
@testable import ClientKit

final class PhotoLocationClientTests: XCTestCase {
    func test_coordinate_readsGPSFromExif() throws {
        let url = Bundle.module.url(forResource: "gps-tagged", withExtension: "jpg")
        let data = try Data(contentsOf: XCTUnwrap(url))

        let client = PhotoLocationClient.liveValue
        let coord = try XCTUnwrap(client.coordinate(data))

        // gps-tagged.jpg is tagged at approx (37.7749, -122.4194).
        XCTAssertEqual(coord.latitude, 37.7749, accuracy: 0.01)
        XCTAssertEqual(coord.longitude, -122.4194, accuracy: 0.01)
    }

    func test_coordinate_returnsNil_whenNoGPS() {
        let client = PhotoLocationClient.liveValue
        XCTAssertNil(client.coordinate(Data([0xFF, 0xD8, 0xFF])))
    }
}
```

> Note: create `gps-tagged.jpg` with `exiftool -GPSLatitude=37.7749 -GPSLatitudeRef=N -GPSLongitude=122.4194 -GPSLongitudeRef=W test.jpg` (or any tool). If exiftool is unavailable, adjust the asserted coordinate to match whatever GPS-tagged JPEG you add.

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ClientKitTests`
Expected: FAIL — `cannot find 'PhotoLocationClient' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/ClientKit/PhotoLocationClient.swift`:
```swift
import Foundation
import ImageIO
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PhotoLocationClient: Sendable {
    public var coordinate: @Sendable (_ imageData: Data) -> Coordinate?
}

extension PhotoLocationClient: DependencyKey {
    public static let liveValue = PhotoLocationClient(
        coordinate: { data in
            guard
                let src = CGImageSourceCreateWithData(data as CFData, nil),
                let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
                let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
            else { return nil }
            let latitude = latRef.uppercased() == "S" ? -lat : lat
            let longitude = lonRef.uppercased() == "W" ? -lon : lon
            return Coordinate(latitude: latitude, longitude: longitude)
        }
    )
}

extension PhotoLocationClient: TestDependencyKey {
    public static let testValue = PhotoLocationClient()
    public static let previewValue = PhotoLocationClient(
        coordinate: { _ in Coordinate(latitude: 33.5902, longitude: 130.4017) }
    )
}

public extension DependencyValues {
    var photoLocation: PhotoLocationClient {
        get { self[PhotoLocationClient.self] }
        set { self[PhotoLocationClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ClientKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(clientkit): PhotoLocationClient reading GPS from EXIF

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: `PlaceSearchClient` (mock live impl)

**Files:**
- Create: `Sources/ClientKit/PlaceSearchClient.swift`
- Test: `Tests/ClientKitTests/PlaceSearchClientTests.swift`

**Interfaces:**
- Consumes: `Coordinate`, `PlaceInfo` from `Models`.
- Produces:
  - `@DependencyClient struct PlaceSearchClient: Sendable { var nearby: @Sendable (Coordinate) async throws -> [PlaceInfo] }`
  - `liveValue` returns deterministic mock nearby places (Google integration deferred). `DependencyValues.placeSearch`.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/PlaceSearchClientTests.swift`:
```swift
import XCTest
import Models
@testable import ClientKit

final class PlaceSearchClientTests: XCTestCase {
    func test_liveValue_returnsNonEmptyMockNearbyPlaces() async throws {
        let client = PlaceSearchClient.liveValue
        let places = try await client.nearby(Coordinate(latitude: 33.59, longitude: 130.40))
        XCTAssertFalse(places.isEmpty)
        XCTAssertTrue(places.allSatisfy { !$0.name.isEmpty })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ClientKitTests`
Expected: FAIL — `cannot find 'PlaceSearchClient' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/ClientKit/PlaceSearchClient.swift`:
```swift
import Foundation
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PlaceSearchClient: Sendable {
    public var nearby: @Sendable (_ coordinate: Coordinate) async throws -> [PlaceInfo]
}

extension PlaceSearchClient: DependencyKey {
    // v1: Google Places is not wired yet. Return deterministic mock data near
    // the requested coordinate so the flow is fully exercisable offline.
    public static let liveValue = PlaceSearchClient(
        nearby: { coordinate in
            let names = ["라멘 이치란", "스시로", "규카츠 모토무라", "이키나리 스테이크", "코메다 커피"]
            return names.enumerated().map { index, name in
                PlaceInfo(
                    id: "mock_\(index)",
                    name: name,
                    address: "후쿠오카시 근처 \(index + 1)번지",
                    coordinate: Coordinate(
                        latitude: coordinate.latitude + Double(index) * 0.0003,
                        longitude: coordinate.longitude + Double(index) * 0.0003
                    ),
                    googlePlaceId: nil
                )
            }
        }
    )
}

extension PlaceSearchClient: TestDependencyKey {
    public static let testValue = PlaceSearchClient()
    public static let previewValue = PlaceSearchClient(
        nearby: { _ in
            [PlaceInfo(id: "preview", name: "미리보기 식당", address: "미리보기 주소")]
        }
    )
}

public extension DependencyValues {
    var placeSearch: PlaceSearchClient {
        get { self[PlaceSearchClient.self] }
        set { self[PlaceSearchClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ClientKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(clientkit): PlaceSearchClient with mock nearby places

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: `PersistenceClient` (SwiftData ModelActor → DTOs)

**Files:**
- Create: `Sources/ClientKit/PersistenceClient.swift`
- Test: `Tests/ClientKitTests/PersistenceClientTests.swift`

**Interfaces:**
- Consumes: `Meal`, `FoodCutout`, `MealSnapshot`, `CutoutSnapshot`, `PlaceInfo` from `Models`.
- Produces:
  - `struct NewCutout: Sendable { var pngData: Data; var label: String? }`
  - `@DependencyClient struct PersistenceClient: Sendable { var saveMeal: @Sendable (_ place: PlaceInfo?, _ memo: String, _ rating: Int?, _ cutouts: [NewCutout]) async throws -> MealSnapshot; var allCutouts: @Sendable () async throws -> [CutoutSnapshot]; var meal: @Sendable (_ id: UUID) async throws -> MealSnapshot?; var deleteMeal: @Sendable (_ id: UUID) async throws -> Void }`
  - `PersistenceClient.live(container: ModelContainer, imageStore: ImageStore) -> PersistenceClient`
  - `DependencyValues.persistence`, plus `DependencyValues.modelContainer` helper that builds the on-disk container.
- Note: `allCutouts` returns cutouts newest-first for the collection wall.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/PersistenceClientTests.swift`:
```swift
import XCTest
import SwiftData
import Models
@testable import ClientKit

final class PersistenceClientTests: XCTestCase {
    func test_saveMeal_thenAllCutouts_roundTrips() async throws {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var savedNames: [String] = []
        let store = ImageStore(
            save: { _ in let n = "\(savedNames.count).png"; savedNames.append(n); return n },
            load: { _ in nil },
            delete: { _ in }
        )
        let client = PersistenceClient.live(container: container, imageStore: store)

        let place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")
        let snap = try await client.saveMeal(
            place, "맛있다", 5,
            [NewCutout(pngData: Data([1]), label: "라멘"),
             NewCutout(pngData: Data([2]), label: nil)]
        )

        XCTAssertEqual(snap.cutouts.count, 2)
        XCTAssertEqual(snap.place?.name, "라멘집")

        let all = try await client.allCutouts()
        XCTAssertEqual(all.count, 2)

        let fetched = try await client.meal(snap.id)
        XCTAssertEqual(fetched?.memo, "맛있다")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test ClientKitTests`
Expected: FAIL — `cannot find 'PersistenceClient' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/ClientKit/PersistenceClient.swift`:
```swift
import Foundation
import SwiftData
import Dependencies
import DependenciesMacros
import Models

public struct NewCutout: Sendable {
    public var pngData: Data
    public var label: String?
    public init(pngData: Data, label: String? = nil) {
        self.pngData = pngData
        self.label = label
    }
}

@DependencyClient
public struct PersistenceClient: Sendable {
    public var saveMeal: @Sendable (
        _ place: PlaceInfo?, _ memo: String, _ rating: Int?, _ cutouts: [NewCutout]
    ) async throws -> MealSnapshot
    public var allCutouts: @Sendable () async throws -> [CutoutSnapshot]
    public var meal: @Sendable (_ id: UUID) async throws -> MealSnapshot?
    public var deleteMeal: @Sendable (_ id: UUID) async throws -> Void
}

@ModelActor
actor PersistenceActor {
    var imageStore: ImageStore!

    func save(place: PlaceInfo?, memo: String, rating: Int?, cutouts: [NewCutout]) throws -> MealSnapshot {
        let meal = Meal(memo: memo, rating: rating)
        meal.place = place
        for new in cutouts {
            let name = try imageStore.save(new.pngData)
            let cutout = FoodCutout(fileName: name, label: new.label)
            cutout.meal = meal
            meal.cutouts.append(cutout)
        }
        modelContext.insert(meal)
        try modelContext.save()
        return meal.snapshot()
    }

    func allCutouts() throws -> [CutoutSnapshot] {
        let descriptor = FetchDescriptor<FoodCutout>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    func meal(id: UUID) throws -> MealSnapshot? {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        guard let meal = try modelContext.fetch(descriptor).first else { return }
        for cutout in meal.cutouts { try? imageStore.delete(cutout.fileName) }
        modelContext.delete(meal)
        try modelContext.save()
    }
}

public extension PersistenceClient {
    static func live(container: ModelContainer, imageStore: ImageStore) -> PersistenceClient {
        let actor = PersistenceActor(modelContainer: container)
        Task { await actor.setImageStore(imageStore) }
        return PersistenceClient(
            saveMeal: { place, memo, rating, cutouts in
                try await actor.save(place: place, memo: memo, rating: rating, cutouts: cutouts)
            },
            allCutouts: { try await actor.allCutouts() },
            meal: { id in try await actor.meal(id: id) },
            deleteMeal: { id in try await actor.delete(id: id) }
        )
    }
}

extension PersistenceActor {
    func setImageStore(_ store: ImageStore) { self.imageStore = store }
}

extension PersistenceClient: TestDependencyKey {
    public static let testValue = PersistenceClient()
    public static let previewValue = PersistenceClient(
        saveMeal: { place, memo, rating, cutouts in
            MealSnapshot(id: UUID(), eatenAt: Date(), place: place, memo: memo, rating: rating,
                         cutouts: cutouts.enumerated().map {
                             CutoutSnapshot(id: UUID(), fileName: "\($0.offset).png",
                                            createdAt: Date(), label: $0.element.label)
                         })
        },
        allCutouts: { [] },
        meal: { _ in nil },
        deleteMeal: { _ in }
    )
}

public extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
```

> Note: `PersistenceClient` has no `DependencyKey.liveValue` because the live value needs a `ModelContainer` built at app launch. The app wires `.live(container:imageStore:)` in Task 14. Tests and previews use `testValue`/`previewValue`.

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test ClientKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(clientkit): PersistenceClient over SwiftData ModelActor

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 3 — Features (FeatureKit, TCA)

### Task 10: `CollectionFeature` (home wall) reducer

**Files:**
- Create: `Sources/FeatureKit/Collection/CollectionFeature.swift`
- Test: `Tests/FeatureKitTests/CollectionFeatureTests.swift`
- Delete: `Sources/FeatureKit/FeatureKitPlaceholder.swift`

**Interfaces:**
- Consumes: `PersistenceClient.allCutouts`, `CutoutSnapshot`.
- Produces:
  - `@Reducer struct CollectionFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot] = []; var isLoading = false }` and `enum Action { case onAppear; case cutoutsLoaded([CutoutSnapshot]); case cutoutTapped(UUID) }`.
  - `cutoutTapped` is handled by the parent (delegate-free: parent observes via navigation in Task 14); in this task it is a no-op returning `.none`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/CollectionFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CollectionFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_loadsCutouts() async {
        let sample = [
            CutoutSnapshot(id: UUID(), fileName: "a.png", createdAt: Date(), label: "라멘"),
        ]
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { sample }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = sample
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test FeatureKitTests`
Expected: FAIL — `cannot find 'CollectionFeature' in scope`.

- [ ] **Step 3: Write the implementation, delete placeholder**

`Sources/FeatureKit/Collection/CollectionFeature.swift`:
```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CollectionFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot] = []
        public var isLoading = false
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case cutoutTapped(UUID)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let cutouts = try await persistence.allCutouts()
                    await send(.cutoutsLoaded(cutouts))
                }
            case let .cutoutsLoaded(cutouts):
                state.isLoading = false
                state.cutouts = cutouts
                return .none
            case .cutoutTapped:
                // Navigation handled by the parent (RootFeature).
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test FeatureKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(featurekit): CollectionFeature reducer loading cutouts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: `PlacePickerFeature` reducer

**Files:**
- Create: `Sources/FeatureKit/Capture/PlacePickerFeature.swift`
- Test: `Tests/FeatureKitTests/PlacePickerFeatureTests.swift`

**Interfaces:**
- Consumes: `PlaceSearchClient.nearby`, `Coordinate`, `PlaceInfo`.
- Produces:
  - `@Reducer struct PlacePickerFeature` with `@ObservableState struct State: Equatable { var coordinate: Coordinate?; var places: [PlaceInfo] = []; var isLoading = false; var manualName = ""; var selected: PlaceInfo? }` and `enum Action: Equatable { case task; case placesLoaded([PlaceInfo]); case placeSelected(PlaceInfo); case manualNameChanged(String); case useManualEntry }` plus `BindingAction` not required.
  - After `useManualEntry`, `selected` becomes a `PlaceInfo` built from `manualName` (id `"manual"`).

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/PlacePickerFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class PlacePickerFeatureTests: XCTestCase {
    @MainActor
    func test_task_loadsNearbyPlaces() async {
        let places = [PlaceInfo(id: "1", name: "라멘집", address: "후쿠오카")]
        let store = TestStore(
            initialState: PlacePickerFeature.State(coordinate: Coordinate(latitude: 1, longitude: 2))
        ) {
            PlacePickerFeature()
        } withDependencies: {
            $0.placeSearch.nearby = { _ in places }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.placesLoaded) {
            $0.isLoading = false
            $0.places = places
        }
    }

    @MainActor
    func test_manualEntry_setsSelected() async {
        let store = TestStore(initialState: PlacePickerFeature.State()) {
            PlacePickerFeature()
        }
        await store.send(.manualNameChanged("우리집")) { $0.manualName = "우리집" }
        await store.send(.useManualEntry) {
            $0.selected = PlaceInfo(id: "manual", name: "우리집", address: "")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test FeatureKitTests`
Expected: FAIL — `cannot find 'PlacePickerFeature' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/FeatureKit/Capture/PlacePickerFeature.swift`:
```swift
import ComposableArchitecture
import Models
import ClientKit

@Reducer
public struct PlacePickerFeature {
    @ObservableState
    public struct State: Equatable {
        public var coordinate: Coordinate?
        public var places: [PlaceInfo] = []
        public var isLoading = false
        public var manualName = ""
        public var selected: PlaceInfo?
        public init(coordinate: Coordinate? = nil) { self.coordinate = coordinate }
    }

    public enum Action: Equatable {
        case task
        case placesLoaded([PlaceInfo])
        case placeSelected(PlaceInfo)
        case manualNameChanged(String)
        case useManualEntry
    }

    @Dependency(\.placeSearch) var placeSearch

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard let coordinate = state.coordinate else { return .none }
                state.isLoading = true
                return .run { send in
                    let places = try await placeSearch.nearby(coordinate)
                    await send(.placesLoaded(places))
                }
            case let .placesLoaded(places):
                state.isLoading = false
                state.places = places
                return .none
            case let .placeSelected(place):
                state.selected = place
                return .none
            case let .manualNameChanged(name):
                state.manualName = name
                return .none
            case .useManualEntry:
                state.selected = PlaceInfo(id: "manual", name: state.manualName, address: "")
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test FeatureKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(featurekit): PlacePickerFeature reducer (nearby + manual)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 12: `CaptureFeature` reducer (the core flow)

**Files:**
- Create: `Sources/FeatureKit/Capture/CaptureFeature.swift`
- Test: `Tests/FeatureKitTests/CaptureFeatureTests.swift`

**Interfaces:**
- Consumes: `FoodCutoutClient.extract`, `PhotoLocationClient.coordinate`, `PersistenceClient.saveMeal`, `PlacePickerFeature`, `Cutout`, `NewCutout`, `Coordinate`, `MealSnapshot`.
- Produces:
  - `@Reducer struct CaptureFeature` with:
    - `@ObservableState struct State: Equatable { var photoData: Data?; var coordinate: Coordinate?; var candidates: [CutoutCandidate] = []; var isProcessing = false; var memo = ""; var rating: Int?; @Presents var placePicker: PlacePickerFeature.State?; var savedMeal: MealSnapshot? }`
    - `struct CutoutCandidate: Equatable, Identifiable { let id: UUID; let pngData: Data; var isSelected: Bool }`
    - `enum Action: Equatable { case photoPicked(Data); case processingFinished(coordinate: Coordinate?, cutouts: [Data]); case toggleCandidate(UUID); case memoChanged(String); case ratingChanged(Int?); case choosePlaceTapped; case placePicker(PresentationAction<PlacePickerFeature.Action>); case saveTapped; case saved(MealSnapshot) }`
  - Selecting a place in the presented picker copies `selected` into the meal on save.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/CaptureFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit
@testable import ClientKit

final class CaptureFeatureTests: XCTestCase {
    @MainActor
    func test_photoPicked_extractsCutoutsAndCoordinate() async {
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.foodCutout.extract = { _ in [Cutout(pngData: Data([1])), Cutout(pngData: Data([2]))] }
            $0.photoLocation.coordinate = { _ in Coordinate(latitude: 1, longitude: 2) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.photoPicked(Data([9]))) {
            $0.photoData = Data([9])
            $0.isProcessing = true
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.coordinate = Coordinate(latitude: 1, longitude: 2)
            $0.candidates = [
                .init(id: $0.candidates[0].id, pngData: Data([1]), isSelected: true),
                .init(id: $0.candidates[1].id, pngData: Data([2]), isSelected: true),
            ]
        }
    }

    @MainActor
    func test_saveTapped_persistsSelectedCutouts() async {
        let savedMeal = MealSnapshot(id: UUID(), eatenAt: Date(), place: nil,
                                     memo: "맛있다", rating: 5, cutouts: [])
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [
                    .init(id: UUID(), pngData: Data([1]), isSelected: true),
                    .init(id: UUID(), pngData: Data([2]), isSelected: false),
                ],
                memo: "맛있다",
                rating: 5
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveMeal = { _, memo, rating, cutouts in
                XCTAssertEqual(cutouts.count, 1) // only the selected one
                XCTAssertEqual(memo, "맛있다")
                XCTAssertEqual(rating, 5)
                return savedMeal
            }
        }

        await store.send(.saveTapped)
        await store.receive(\.saved) { $0.savedMeal = savedMeal }
    }
}
```

> Note: give `CaptureFeature.State` a memberwise `init` exposing `candidates`, `memo`, `rating` so the second test can seed them.

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test FeatureKitTests`
Expected: FAIL — `cannot find 'CaptureFeature' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/FeatureKit/Capture/CaptureFeature.swift`:
```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CaptureFeature {
    public struct CutoutCandidate: Equatable, Identifiable {
        public let id: UUID
        public let pngData: Data
        public var isSelected: Bool
        public init(id: UUID = UUID(), pngData: Data, isSelected: Bool = true) {
            self.id = id
            self.pngData = pngData
            self.isSelected = isSelected
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var photoData: Data?
        public var coordinate: Coordinate?
        public var candidates: [CutoutCandidate]
        public var isProcessing = false
        public var memo: String
        public var rating: Int?
        @Presents public var placePicker: PlacePickerFeature.State?
        public var savedMeal: MealSnapshot?

        public init(
            photoData: Data? = nil,
            coordinate: Coordinate? = nil,
            candidates: [CutoutCandidate] = [],
            memo: String = "",
            rating: Int? = nil
        ) {
            self.photoData = photoData
            self.coordinate = coordinate
            self.candidates = candidates
            self.memo = memo
            self.rating = rating
        }

        public var selectedPlace: PlaceInfo? { placePicker?.selected }
    }

    public enum Action: Equatable {
        case photoPicked(Data)
        case processingFinished(coordinate: Coordinate?, cutouts: [Data])
        case toggleCandidate(UUID)
        case memoChanged(String)
        case ratingChanged(Int?)
        case choosePlaceTapped
        case placePicker(PresentationAction<PlacePickerFeature.Action>)
        case saveTapped
        case saved(MealSnapshot)
    }

    @Dependency(\.foodCutout) var foodCutout
    @Dependency(\.photoLocation) var photoLocation
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .photoPicked(data):
                state.photoData = data
                state.isProcessing = true
                return .run { send in
                    async let cutouts = foodCutout.extract(data)
                    let coordinate = photoLocation.coordinate(data)
                    let pngs = try await cutouts.map(\.pngData)
                    await send(.processingFinished(coordinate: coordinate, cutouts: pngs))
                }

            case let .processingFinished(coordinate, cutouts):
                state.isProcessing = false
                state.coordinate = coordinate
                state.candidates = cutouts.map { CutoutCandidate(pngData: $0, isSelected: true) }
                return .none

            case let .toggleCandidate(id):
                guard let idx = state.candidates.firstIndex(where: { $0.id == id }) else { return .none }
                state.candidates[idx].isSelected.toggle()
                return .none

            case let .memoChanged(memo):
                state.memo = memo
                return .none

            case let .ratingChanged(rating):
                state.rating = rating
                return .none

            case .choosePlaceTapped:
                state.placePicker = PlacePickerFeature.State(coordinate: state.coordinate)
                return .none

            case .placePicker:
                return .none

            case .saveTapped:
                let place = state.placePicker?.selected
                let memo = state.memo
                let rating = state.rating
                let selected = state.candidates
                    .filter(\.isSelected)
                    .map { NewCutout(pngData: $0.pngData, label: nil) }
                return .run { send in
                    let meal = try await persistence.saveMeal(place, memo, rating, selected)
                    await send(.saved(meal))
                }

            case let .saved(meal):
                state.savedMeal = meal
                return .none
            }
        }
        .ifLet(\.$placePicker, action: \.placePicker) {
            PlacePickerFeature()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test FeatureKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(featurekit): CaptureFeature core flow reducer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 13: `MealDetailFeature` reducer

**Files:**
- Create: `Sources/FeatureKit/MealDetail/MealDetailFeature.swift`
- Test: `Tests/FeatureKitTests/MealDetailFeatureTests.swift`

**Interfaces:**
- Consumes: `PersistenceClient.meal`, `PersistenceClient.deleteMeal`, `MealSnapshot`.
- Produces:
  - `@Reducer struct MealDetailFeature` with `@ObservableState struct State: Equatable { let mealID: UUID; var meal: MealSnapshot?; init(mealID: UUID) }` and `enum Action: Equatable { case task; case mealLoaded(MealSnapshot?); case deleteTapped; case deleted }`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/MealDetailFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class MealDetailFeatureTests: XCTestCase {
    @MainActor
    func test_task_loadsMeal() async {
        let id = UUID()
        let meal = MealSnapshot(id: id, eatenAt: Date(), place: nil, memo: "hi", rating: nil, cutouts: [])
        let store = TestStore(initialState: MealDetailFeature.State(mealID: id)) {
            MealDetailFeature()
        } withDependencies: {
            $0.persistence.meal = { _ in meal }
        }
        await store.send(.task)
        await store.receive(\.mealLoaded) { $0.meal = meal }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test FeatureKitTests`
Expected: FAIL — `cannot find 'MealDetailFeature' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/FeatureKit/MealDetail/MealDetailFeature.swift`:
```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct MealDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let mealID: UUID
        public var meal: MealSnapshot?
        public init(mealID: UUID) { self.mealID = mealID }
    }

    public enum Action: Equatable {
        case task
        case mealLoaded(MealSnapshot?)
        case deleteTapped
        case deleted
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let id = state.mealID
                return .run { send in await send(.mealLoaded(try await persistence.meal(id))) }
            case let .mealLoaded(meal):
                state.meal = meal
                return .none
            case .deleteTapped:
                let id = state.mealID
                return .run { send in
                    try await persistence.deleteMeal(id)
                    await send(.deleted)
                }
            case .deleted:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test FeatureKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(featurekit): MealDetailFeature reducer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 14: `RootFeature` (tabs + navigation) reducer

**Files:**
- Create: `Sources/FeatureKit/Root/RootFeature.swift`
- Test: `Tests/FeatureKitTests/RootFeatureTests.swift`

**Interfaces:**
- Consumes: `CollectionFeature`, `CaptureFeature`, `MealDetailFeature`.
- Produces:
  - `@Reducer struct RootFeature` with:
    - `enum Tab: Equatable { case collection, capture }`
    - `@ObservableState struct State: Equatable { var tab: Tab = .collection; var collection = CollectionFeature.State(); var capture = CaptureFeature.State(); var path = StackState<MealDetailFeature.State>() }`
    - `enum Action { case tabChanged(Tab); case collection(CollectionFeature.Action); case capture(CaptureFeature.Action); case pushDetail(UUID); case path(StackAction<MealDetailFeature.State, MealDetailFeature.Action>) }`
  - When `CollectionFeature` emits `.cutoutTapped(cutoutID)`, Root looks up the owning meal via a new `PersistenceClient.mealByCutout(cutoutID)` and pushes `MealDetailFeature` for that meal onto `path`. This keeps `CutoutSnapshot` unchanged (already committed in Task 4) and is the minimal, honest way to navigate from a cutout to its meal.

> **New client method (added in Step 1 below):** `PersistenceClient.mealByCutout: @Sendable (_ cutoutID: UUID) async throws -> MealSnapshot?` — implemented in `PersistenceActor` by fetching the `FoodCutout` by id and returning `cutout.meal?.snapshot()`.

- [ ] **Step 1: Extend `PersistenceClient` with `mealByCutout` (TDD)**

Add to `Tests/ClientKitTests/PersistenceClientTests.swift` a new test:
```swift
func test_mealByCutout_returnsOwningMeal() async throws {
    let container = try ModelContainer(
        for: Meal.self, FoodCutout.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let store = ImageStore(save: { _ in "n.png" }, load: { _ in nil }, delete: { _ in })
    let client = PersistenceClient.live(container: container, imageStore: store)
    let snap = try await client.saveMeal(nil, "m", nil, [NewCutout(pngData: Data([1]), label: nil)])
    let cutoutID = snap.cutouts[0].id
    let owning = try await client.mealByCutout(cutoutID)
    XCTAssertEqual(owning?.id, snap.id)
}
```
Run: `tuist generate --no-open && tuist test ClientKitTests` → FAIL (`mealByCutout` missing).

Then in `Sources/ClientKit/PersistenceClient.swift`:
- Add to the `@DependencyClient struct`: `public var mealByCutout: @Sendable (_ cutoutID: UUID) async throws -> MealSnapshot?`
- Add to `PersistenceActor`:
```swift
func mealByCutout(id: UUID) throws -> MealSnapshot? {
    let descriptor = FetchDescriptor<FoodCutout>(predicate: #Predicate { $0.id == id })
    return try modelContext.fetch(descriptor).first?.meal?.snapshot()
}
```
- Add to `live(...)`: `mealByCutout: { id in try await actor.mealByCutout(id: id) },`
- Add to `previewValue`: `mealByCutout: { _ in nil },`

Run: `tuist test ClientKitTests` → PASS. Commit:
```bash
git add -A
git commit -m "feat(clientkit): PersistenceClient.mealByCutout for navigation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 2: Write the failing RootFeature test**

`Tests/FeatureKitTests/RootFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RootFeatureTests: XCTestCase {
    @MainActor
    func test_cutoutTapped_pushesMealDetail() async {
        let mealID = UUID()
        let cutoutID = UUID()
        let meal = MealSnapshot(id: mealID, eatenAt: Date(), place: nil, memo: "", rating: nil, cutouts: [])
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.persistence.mealByCutout = { _ in meal }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.collection(.cutoutTapped(cutoutID)))
        await store.receive(\.pushDetail) {
            $0.path.append(MealDetailFeature.State(mealID: mealID))
        }
    }

    @MainActor
    func test_tabChanged_updatesTab() async {
        let store = TestStore(initialState: RootFeature.State()) { RootFeature() }
        await store.send(.tabChanged(.capture)) { $0.tab = .capture }
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `tuist generate --no-open && tuist test FeatureKitTests`
Expected: FAIL — `cannot find 'RootFeature' in scope`.

- [ ] **Step 4: Write the implementation**

`Sources/FeatureKit/Root/RootFeature.swift`:
```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct RootFeature {
    public enum Tab: Equatable { case collection, capture }

    @ObservableState
    public struct State: Equatable {
        public var tab: Tab = .collection
        public var collection = CollectionFeature.State()
        public var capture = CaptureFeature.State()
        public var path = StackState<MealDetailFeature.State>()
        public init() {}
    }

    public enum Action {
        case tabChanged(Tab)
        case collection(CollectionFeature.Action)
        case capture(CaptureFeature.Action)
        case pushDetail(UUID)
        case path(StackAction<MealDetailFeature.State, MealDetailFeature.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.collection, action: \.collection) { CollectionFeature() }
        Scope(state: \.capture, action: \.capture) { CaptureFeature() }

        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.tab = tab
                return .none

            case let .collection(.cutoutTapped(cutoutID)):
                return .run { send in
                    if let meal = try await persistence.mealByCutout(cutoutID) {
                        await send(.pushDetail(meal.id))
                    }
                }

            case let .pushDetail(mealID):
                state.path.append(MealDetailFeature.State(mealID: mealID))
                return .none

            // When a save finishes on the capture tab, refresh the collection and switch to it.
            case .capture(.saved):
                state.tab = .collection
                return .send(.collection(.onAppear))

            // Pop detail after a delete.
            case let .path(.element(id: id, action: .deleted)):
                state.path.pop(from: id)
                return .send(.collection(.onAppear))

            case .collection, .capture, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            MealDetailFeature()
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `tuist test FeatureKitTests`
Expected: PASS. (`.capture(.saved)` returning `.send(.collection(.onAppear))` may require `exhaustivity = .off` in those tests, already set.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(featurekit): RootFeature tabs + meal-detail navigation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 4 — Views & App wire-up

### Task 15: SwiftUI views for each feature

**Files:**
- Create: `Sources/FeatureKit/Collection/CollectionView.swift`
- Create: `Sources/FeatureKit/Capture/CaptureView.swift`
- Create: `Sources/FeatureKit/Capture/PlacePickerView.swift`
- Create: `Sources/FeatureKit/MealDetail/MealDetailView.swift`
- Create: `Sources/FeatureKit/Root/RootView.swift`
- Create: `Sources/FeatureKit/Support/CutoutImage.swift`

**Interfaces:**
- Consumes: all feature reducers above; `ImageStore.cutoutsDirectory` for loading PNGs by file name.
- Produces: `public struct RootView: View { public init(store: StoreOf<RootFeature>) }` and the subordinate views. These are UI-only; no new reducer logic. Verified by building, not unit tests.

- [ ] **Step 1: Write `CutoutImage.swift` (loads a PNG by file name from disk, or raw Data)**

```swift
import SwiftUI
import ClientKit

public struct CutoutImage: View {
    let data: Data?
    public init(fileName: String) {
        self.data = ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(fileName)
    }
    public init(data: Data) { self.data = data }

    public var body: some View {
        if let data, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary)
        }
    }
}
```

- [ ] **Step 2: Write `CollectionView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.cutouts) { cutout in
                    Button { store.send(.cutoutTapped(cutout.id)) } label: {
                        CutoutImage(fileName: cutout.fileName)
                            .frame(height: 100)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .overlay {
            if store.cutouts.isEmpty && !store.isLoading {
                ContentUnavailableView("아직 누끼가 없어요", systemImage: "fork.knife",
                                       description: Text("음식 사진을 찍어 첫 누끼를 담아보세요!"))
            }
        }
        .navigationTitle("컬렉션")
        .task { store.send(.onAppear) }
    }
}
```

- [ ] **Step 3: Write `PlacePickerView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct PlacePickerView: View {
    @Bindable var store: StoreOf<PlacePickerFeature>
    public init(store: StoreOf<PlacePickerFeature>) { self.store = store }

    public var body: some View {
        List {
            Section("근처 식당") {
                ForEach(store.places) { place in
                    Button {
                        store.send(.placeSelected(place))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                Text(place.address).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selected?.id == place.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("직접 입력") {
                TextField("식당 이름", text: Binding(
                    get: { store.manualName },
                    set: { store.send(.manualNameChanged($0)) }
                ))
                Button("이 이름으로 사용") { store.send(.useManualEntry) }
                    .disabled(store.manualName.isEmpty)
            }
        }
        .overlay { if store.isLoading { ProgressView() } }
        .navigationTitle("식당 선택")
        .task { store.send(.task) }
    }
}
```

- [ ] **Step 4: Write `CaptureView.swift`** (PhotosPicker + candidate selection + place + save)

```swift
import SwiftUI
import PhotosUI
import ComposableArchitecture

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItem: PhotosPickerItem?
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("음식 사진 고르기", systemImage: "camera")
                    }
                }
                if store.isProcessing { ProgressView("음식 누끼 따는 중…") }

                if !store.candidates.isEmpty {
                    Section("담을 누끼 고르기") {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(store.candidates) { candidate in
                                    Button { store.send(.toggleCandidate(candidate.id)) } label: {
                                        CutoutImage(data: candidate.pngData)
                                            .frame(width: 90, height: 90)
                                            .overlay(alignment: .topTrailing) {
                                                Image(systemName: candidate.isSelected
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .padding(4)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Section("한 끼 정보") {
                        Button {
                            store.send(.choosePlaceTapped)
                        } label: {
                            HStack {
                                Text("식당")
                                Spacer()
                                Text(store.placePicker?.selected?.name ?? "선택 안 함")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("메모", text: Binding(
                            get: { store.memo },
                            set: { store.send(.memoChanged($0)) }
                        ))
                        Stepper("별점: \(store.rating.map(String.init) ?? "-")",
                                value: Binding(
                                    get: { store.rating ?? 0 },
                                    set: { store.send(.ratingChanged($0)) }
                                ), in: 0...5)
                    }
                    Section {
                        Button("다이어리에 저장") { store.send(.saveTapped) }
                            .disabled(!store.candidates.contains(where: \.isSelected))
                    }
                }
            }
            .navigationTitle("한 끼 담기")
            .sheet(item: $store.scope(state: \.placePicker, action: \.placePicker)) { pickerStore in
                NavigationStack { PlacePickerView(store: pickerStore) }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.send(.photoPicked(data))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 5: Write `MealDetailView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct MealDetailView: View {
    @Bindable var store: StoreOf<MealDetailFeature>
    public init(store: StoreOf<MealDetailFeature>) { self.store = store }

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScrollView {
            if let meal = store.meal {
                VStack(alignment: .leading, spacing: 16) {
                    if let place = meal.place { Text(place.name).font(.title2.bold()) }
                    Text(meal.eatenAt, style: .date).foregroundStyle(.secondary)
                    if let rating = meal.rating { Text(String(repeating: "⭐️", count: rating)) }
                    if !meal.memo.isEmpty { Text(meal.memo) }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(meal.cutouts) { cutout in
                            CutoutImage(fileName: cutout.fileName).frame(height: 100)
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .navigationTitle("한 끼 기록")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("삭제", role: .destructive) { store.send(.deleteTapped) }
            }
        }
        .task { store.send(.task) }
    }
}
```

- [ ] **Step 6: Write `RootView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>
    public init(store: StoreOf<RootFeature>) { self.store = store }

    public var body: some View {
        TabView(selection: Binding(
            get: { store.tab },
            set: { store.send(.tabChanged($0)) }
        )) {
            NavigationStack(
                path: $store.scope(state: \.path, action: \.path)
            ) {
                CollectionView(store: store.scope(state: \.collection, action: \.collection))
            } destination: { detailStore in
                MealDetailView(store: detailStore)
            }
            .tabItem { Label("컬렉션", systemImage: "square.grid.2x2") }
            .tag(RootFeature.Tab.collection)

            CaptureView(store: store.scope(state: \.capture, action: \.capture))
                .tabItem { Label("담기", systemImage: "plus.circle") }
                .tag(RootFeature.Tab.capture)
        }
    }
}
```

- [ ] **Step 7: Build to verify all views compile**

Run: `tuist generate --no-open && tuist build FoodDiary`
Expected: `Build Succeeded`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(featurekit): SwiftUI views for all features

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 16: App entry — build container, wire PersistenceClient, mount RootView

**Files:**
- Modify: `Sources/FoodDiary/FoodDiaryApp.swift`

**Interfaces:**
- Consumes: `RootFeature`, `RootView`, `PersistenceClient.live`, `ImageStore`, `Meal`, `FoodCutout`.
- Produces: a running app whose `RootFeature` store has the live `PersistenceClient` (on-disk `ModelContainer` + `ImageStore.cutoutsDirectory`) injected.

- [ ] **Step 1: Write the app entry**

`Sources/FoodDiary/FoodDiaryApp.swift`:
```swift
import SwiftUI
import SwiftData
import ComposableArchitecture
import FeatureKit
import ClientKit
import Models

@main
struct FoodDiaryApp: App {
    let store: StoreOf<RootFeature>

    init() {
        let container = try! ModelContainer(for: Meal.self, FoodCutout.self)
        let imageStore = ImageStore.disk(directory: ImageStore.cutoutsDirectory)
        store = Store(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.persistence = .live(container: container, imageStore: imageStore)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
```

- [ ] **Step 2: Build & run on simulator**

Run: `tuist generate --no-open && tuist build FoodDiary`
Expected: `Build Succeeded`. Then launch in the iOS 18 simulator (via the run skill / Simulator tool), pick a food photo, confirm cutouts appear as candidates, save, and see them on the collection wall.

- [ ] **Step 3: Full test sweep**

Run: `tuist test`
Expected: all of `ModelsTests`, `ClientKitTests`, `FeatureKitTests` PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(app): wire live PersistenceClient and mount RootView

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §2 stack/target** → Task 1 (Tuist, TCA, iOS 18), Task 2 (Fastlane). ✅
- **Spec §3 modules** → Task 1 (Models/ClientKit/FeatureKit/App). ✅
- **Spec §4 data model** → Tasks 3–4 (Coordinate/PlaceInfo/Meal/FoodCutout/snapshots), disk PNG policy in Task 5/9. ✅
- **Spec §5 core flow** → Task 12 (CaptureFeature: photo→GPS→cutout→select→place→save). ✅
- **Spec §6 clients (4)** → FoodCutout (6), PhotoLocation (7), PlaceSearch mock (8), Persistence (9). ✅
- **Spec §7 collection wall home** → Tasks 10, 14, 15. ✅
- **Spec §8 testing** → reducer TestStores (10–14), client tests with bundled images (6–7), in-memory persistence (9). ✅
- **Spec §9 tooling/hygiene** → Task 1 (xcconfig/gitignore), Task 2 (fastlane). ✅
- **Ambiguity resolved:** cutout→meal navigation via `PersistenceClient.mealByCutout` (Task 14 Step 1), rather than mutating the committed `CutoutSnapshot` type.

## Notes / Assumptions for the implementer

- TCA API assumes 1.17+ (`@Reducer`, `@ObservableState`, `@Presents`, `StackState`, `store.scope` bindings). If macro/API names differ in the resolved version, adapt to that version's current spelling — behavior is the contract.
- **DEVIATION (2026-07-24) — module linkage & package products (final):** After iterating on link failures under Xcode 26.6, the working config is:
  - Internal modules `Models`/`ClientKit`/`FeatureKit` are **`.staticFramework`** (not dynamic). Dynamic frameworks embed the Point-Free static libs and dead-strip unused symbols, starving test bundles (`TestStore`, `CasePathsCore`) at link time.
  - **`ClientKit` is the single owner of every external package product** — `ComposableArchitecture` (`tca`), `Dependencies`, `DependenciesMacros`, `IssueReporting`, `CasePathsCore` — declared once. They propagate up the static chain, so `FeatureKit` imports TCA transitively (declares only `.target("ClientKit")`) and test targets declare only their framework. Declaring a product on multiple targets double-links the shared TCA closure → duplicate symbols.
  - Why explicit at all: TCA re-exports `Dependencies`/`DependenciesMacros`/`CasePaths` at compile time only; their runtime witnesses (`DependencyKey`/`DependencyValues`, `@DependencyClient`'s `Unimplemented`, `@Reducer`'s `CasePathable`) and transitive `IssueReporting` are not auto-linked under native integration.
  - **App/all-tests build via the `FoodDiary-Workspace` scheme** (Tuist's aggregate); there is no standalone `FoodDiary` app scheme under this config. `tuist test` (no arg) runs all; `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary-Workspace -destination 'generic/platform=iOS Simulator'` builds the app. Verified: full suite green, app links with no duplicate symbols.
- **DEVIATION (2026-07-24) — Vision is device-only:** `VNGenerateForegroundInstanceMaskRequest` cannot create an inference context in the iOS Simulator (`com.apple.Vision Code=9`). The `FoodCutoutClient` live test (Task 6) therefore `XCTSkip`s when extraction throws that error, keeping the `≥1 cutout` assertion meaningful on device. The extraction path was verified end-to-end on macOS hardware (1 instance, ~127 KB PNG) before implementation.
- `tuist test <TargetName>` filters to one test target; `tuist test` runs all. If a Tuist version rejects the target-filter form, fall back to `tuist test` or `tuist test --test-targets <name>`.
- Two test image assets must be added by hand: `Tests/ClientKitTests/Resources/test-food.jpg` (clear plated dish) and `gps-tagged.jpg` (GPS EXIF). The plan notes how to tag GPS with exiftool.
- Vision cutout counts depend on the photo; the CaptureView always lets the user keep/deselect candidates, and 0-candidate photos simply produce an empty selection (user retakes).
