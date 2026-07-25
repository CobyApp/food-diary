# Pastel "Soft Dairy" Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the three existing screens into a NewJeans-style "Soft Pastel Dairy" look via a new design-system layer, with zero changes to reducers, clients, models, or their tests.

**Architecture:** Add `Sources/FeatureKit/DesignSystem/` (color/font/style tokens) and `.../DesignSystem/Components/` (reusable SwiftUI views). Rewrite the six view files to consume those tokens/components. Reducers/state are untouched, so behavior — and every existing unit test — is unchanged. App root pins light mode.

**Tech Stack:** SwiftUI (iOS 18, Swift 6), SF Rounded system font, TCA 1.26 (views only). No new dependencies, no new Tuist target.

## Global Constraints

- View-layer only: never edit `Sources/FeatureKit/*/*Feature.swift`, `ClientKit`, `Models`, or any test's assertions. Existing tests must stay green.
- Light mode only (`.preferredColorScheme(.light)` at app root).
- Typography: `.system(..., design: .rounded)` only — no bundled fonts.
- Design system lives in `Sources/FeatureKit/DesignSystem/`; no new module/target.
- Korean UI strings stay Korean; source comments English only.
- Build the module with `tuist build FeatureKit`; build the app with
  `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator'`. Regenerate after adding files: `tuist generate --no-open`. Never run `tuist install` or edit `Project.swift`.
- Commit messages: conventional commits, English, ending with the trailer
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Design tokens (color / font / style)

**Files:**
- Create: `Sources/FeatureKit/DesignSystem/AppColor.swift`
- Create: `Sources/FeatureKit/DesignSystem/AppFont.swift`
- Create: `Sources/FeatureKit/DesignSystem/AppStyle.swift`
- Test: `Tests/FeatureKitTests/AppColorTests.swift`

**Interfaces:**
- Produces:
  - `Color(hex: UInt)` init; `Color.appMilk/appCard/appBlue/appBlueInk/appPink/appPinkInk/appButter/appButterInk/appInk/appMuted/appTilePink/appTileBlue/appTileButter`
  - `enum StickerTint: CaseIterable { case pink, blue, butter, plain; var color: Color; static func rotating(_ index: Int) -> StickerTint }`
  - `Font.appDisplay/appTitle/appSection/appBody/appCaption`
  - `enum AppRadius { static let card/tile/dropZone: CGFloat }`
  - `View.softShadow() -> some View`

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/AppColorTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import FeatureKit

final class AppColorTests: XCTestCase {
    func test_colorHex_parsesRGBChannels() throws {
        let ui = UIColor(Color(hex: 0x8FBEEA))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), Double(0x8F) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(g), Double(0xBE) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(b), Double(0xEA) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.01)
    }

    func test_stickerTint_rotatesThroughAllCases() {
        XCTAssertEqual(StickerTint.rotating(0), StickerTint.allCases[0])
        XCTAssertEqual(StickerTint.rotating(StickerTint.allCases.count),
                       StickerTint.allCases[0])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=SIMID' -only-testing:FeatureKitTests/AppColorTests`
(Replace `SIMID` with a booted simulator UDID from `xcrun simctl list devices booted`.)
Expected: FAIL — `cannot find 'Color' hex init` / `cannot find 'StickerTint'`.

- [ ] **Step 3: Write `AppColor.swift`**

```swift
import SwiftUI

public extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let appMilk = Color(hex: 0xFCF8F5)
    static let appCard = Color.white
    static let appBlue = Color(hex: 0x8FBEEA)
    static let appBlueInk = Color(hex: 0x5385C4)
    static let appPink = Color(hex: 0xF7C2D6)
    static let appPinkInk = Color(hex: 0xC67191)
    static let appButter = Color(hex: 0xFBE6A6)
    static let appButterInk = Color(hex: 0xB99329)
    static let appInk = Color(hex: 0x4B4A57)
    static let appMuted = Color(hex: 0xA6A2B0)

    static let appTilePink = Color(hex: 0xFDEBF2)
    static let appTileBlue = Color(hex: 0xEAF3FC)
    static let appTileButter = Color(hex: 0xFCF3D6)
}

public enum StickerTint: CaseIterable {
    case pink, blue, butter, plain

    public var color: Color {
        switch self {
        case .pink: return .appTilePink
        case .blue: return .appTileBlue
        case .butter: return .appTileButter
        case .plain: return .appCard
        }
    }

    public static func rotating(_ index: Int) -> StickerTint {
        allCases[((index % allCases.count) + allCases.count) % allCases.count]
    }
}
```

- [ ] **Step 4: Write `AppFont.swift`**

```swift
import SwiftUI

public extension Font {
    static let appDisplay = Font.system(size: 25, weight: .black, design: .rounded)
    static let appTitle = Font.system(size: 20, weight: .heavy, design: .rounded)
    static let appSection = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let appBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let appCaption = Font.system(size: 12, weight: .semibold, design: .rounded)
}
```

- [ ] **Step 5: Write `AppStyle.swift`**

```swift
import SwiftUI

public enum AppRadius {
    public static let card: CGFloat = 20
    public static let tile: CGFloat = 15
    public static let dropZone: CGFloat = 16
}

public struct SoftShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content.shadow(
            color: Color(.sRGB, red: 150 / 255, green: 120 / 255, blue: 180 / 255, opacity: 0.14),
            radius: 12, x: 0, y: 5
        )
    }
}

public extension View {
    func softShadow() -> some View { modifier(SoftShadow()) }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=SIMID' -only-testing:FeatureKitTests/AppColorTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/DesignSystem Tests/FeatureKitTests/AppColorTests.swift
git commit -m "feat(design): pastel color/font/style tokens

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Primitive components

**Files:**
- Create: `Sources/FeatureKit/DesignSystem/Components/StickerTile.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/SoftCard.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/PastelChip.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/PillButton.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/StarRating.swift`

**Interfaces:**
- Consumes: tokens from Task 1.
- Produces:
  - `StickerTile<Content: View>(tint: StickerTint = .plain, @ViewBuilder content: () -> Content)`
  - `SoftCard<Content: View>(@ViewBuilder content: () -> Content)`
  - `PastelChip(_ text: String, glyph: String? = nil, tone: PastelChip.Tone = .blue)` with `enum Tone { case blue, pink, butter }`
  - `PillButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void)`
  - `StarRating(rating: Int?, onChange: ((Int?) -> Void)? = nil)` — `onChange == nil` ⇒ read-only

- [ ] **Step 1: Write `StickerTile.swift`**

```swift
import SwiftUI

public struct StickerTile<Content: View>: View {
    private let tint: StickerTint
    private let content: Content

    public init(tint: StickerTint = .plain, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(tint.color)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
            .softShadow()
    }
}

#Preview {
    HStack {
        StickerTile(tint: .pink) { Text("🍜").font(.system(size: 30)) }
        StickerTile(tint: .blue) { Text("🍰").font(.system(size: 30)) }
    }
    .padding().background(Color.appMilk)
}
```

- [ ] **Step 2: Write `SoftCard.swift`**

```swift
import SwiftUI

public struct SoftCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .softShadow()
    }
}

#Preview {
    SoftCard { Text("존맛탱 🥹").font(.appBody).foregroundStyle(.appInk) }
        .padding().background(Color.appMilk)
}
```

- [ ] **Step 3: Write `PastelChip.swift`**

```swift
import SwiftUI

public struct PastelChip: View {
    public enum Tone { case blue, pink, butter }

    private let text: String
    private let glyph: String?
    private let tone: Tone

    public init(_ text: String, glyph: String? = nil, tone: Tone = .blue) {
        self.text = text
        self.glyph = glyph
        self.tone = tone
    }

    private var background: Color {
        switch tone {
        case .blue: return .appTileBlue
        case .pink: return .appTilePink
        case .butter: return .appTileButter
        }
    }
    private var foreground: Color {
        switch tone {
        case .blue: return .appBlueInk
        case .pink: return .appPinkInk
        case .butter: return .appButterInk
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let glyph { Text(glyph) }
            Text(text)
        }
        .font(.appCaption)
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        PastelChip("라멘집", glyph: "✦", tone: .blue)
        PastelChip("7.24 목", glyph: "📅", tone: .pink)
        PastelChip("메모", tone: .butter)
    }
    .padding().background(Color.appMilk)
}
```

- [ ] **Step 4: Write `PillButton.swift`**

```swift
import SwiftUI

public struct PillButton: View {
    private let title: String
    private let enabled: Bool
    private let action: () -> Void

    public init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Color.appBlue : Color.appMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .softShadow()
    }
}

#Preview {
    VStack {
        PillButton("다이어리에 저장 ♡") {}
        PillButton("비활성", enabled: false) {}
    }
    .padding().background(Color.appMilk)
}
```

- [ ] **Step 5: Write `StarRating.swift`**

```swift
import SwiftUI

public struct StarRating: View {
    private let rating: Int?
    private let onChange: ((Int?) -> Void)?

    /// `onChange == nil` renders a compact read-only row; otherwise an editable
    /// row where tapping a star sets 1...5, and re-tapping the current value clears to nil.
    public init(rating: Int?, onChange: ((Int?) -> Void)? = nil) {
        self.rating = rating
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                let filled = i <= (rating ?? 0)
                Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: onChange == nil ? 15 : 24))
                    .foregroundStyle(filled ? Color.appButterInk : Color.appMuted.opacity(0.5))
                    .onTapGesture {
                        guard let onChange else { return }
                        onChange(rating == i ? nil : i)
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StarRating(rating: 4)
        StarRating(rating: 3, onChange: { _ in })
    }
    .padding().background(Color.appMilk)
}
```

- [ ] **Step 6: Build to verify components compile**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/DesignSystem/Components
git commit -m "feat(design): StickerTile/SoftCard/PastelChip/PillButton/StarRating

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Layout components (scaffold / drop zone / empty state)

**Files:**
- Create: `Sources/FeatureKit/DesignSystem/Components/ScreenScaffold.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/DropZoneCard.swift`
- Create: `Sources/FeatureKit/DesignSystem/Components/EmptyState.swift`

**Interfaces:**
- Consumes: tokens from Task 1.
- Produces:
  - `ScreenScaffold<Content: View>(title: String, doodle: String? = "✦", @ViewBuilder content: () -> Content)` — milk background + large rounded title + scrolling content with bottom inset (96) so the floating tab bar never overlaps.
  - `DropZoneCard<Content: View>(@ViewBuilder label: () -> Content)` — dashed baby-blue rounded card wrapping any tappable label (e.g. a `PhotosPicker`).
  - `EmptyState(systemImage: String, title: String, subtitle: String)`

- [ ] **Step 1: Write `ScreenScaffold.swift`**

```swift
import SwiftUI

public struct ScreenScaffold<Content: View>: View {
    private let title: String
    private let doodle: String?
    private let content: Content

    public init(title: String, doodle: String? = "✦", @ViewBuilder content: () -> Content) {
        self.title = title
        self.doodle = doodle
        self.content = content()
    }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Text(title).font(.appDisplay).foregroundStyle(.appInk)
                        if let doodle { Text(doodle).font(.appDisplay).foregroundStyle(.appBlue) }
                    }
                    .padding(.top, 8)
                    content
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 96)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
```

- [ ] **Step 2: Write `DropZoneCard.swift`**

```swift
import SwiftUI

public struct DropZoneCard<Content: View>: View {
    private let label: Content
    public init(@ViewBuilder label: () -> Content) { self.label = label() }

    public var body: some View {
        label
            .font(.appSection)
            .foregroundStyle(.appBlueInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.appTileBlue.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous)
                    .strokeBorder(Color.appBlue, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            )
    }
}
```

- [ ] **Step 3: Write `EmptyState.swift`**

```swift
import SwiftUI

public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let subtitle: String

    public init(systemImage: String, title: String, subtitle: String) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Color.appBlue)
            Text(title).font(.appTitle).foregroundStyle(.appInk)
            Text(subtitle).font(.appBody).foregroundStyle(.appMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    ScreenScaffold(title: "컬렉션") {
        EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                   subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
    }
}
```

- [ ] **Step 4: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FeatureKit/DesignSystem/Components/ScreenScaffold.swift Sources/FeatureKit/DesignSystem/Components/DropZoneCard.swift Sources/FeatureKit/DesignSystem/Components/EmptyState.swift
git commit -m "feat(design): ScreenScaffold/DropZoneCard/EmptyState

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Reskin CollectionView

**Files:**
- Modify (full replace): `Sources/FeatureKit/Collection/CollectionView.swift`

**Interfaces:**
- Consumes: `ScreenScaffold`, `StickerTile`, `EmptyState`, `StickerTint`, `CutoutImage`.
- Store API (unchanged): `store.cutouts: [CutoutSnapshot]`, `store.isLoading: Bool`, `store.send(.cutoutTapped(cutout.id))`, `store.send(.onAppear)`.

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScreenScaffold(title: "컬렉션") {
            if store.cutouts.isEmpty {
                if !store.isLoading {
                    EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                               subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                        Button { store.send(.cutoutTapped(cutout.id)) } label: {
                            StickerTile(tint: .rotating(index)) {
                                CutoutImage(fileName: cutout.fileName)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
    }
}
```

- [ ] **Step 2: Build & verify no regression**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/Collection/CollectionView.swift
git commit -m "feat(design): reskin CollectionView as pastel sticker wall

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Reskin CaptureView + PlacePickerView

**Files:**
- Modify (full replace): `Sources/FeatureKit/Capture/CaptureView.swift`
- Modify (full replace): `Sources/FeatureKit/Capture/PlacePickerView.swift`

**Interfaces:**
- Consumes: `ScreenScaffold`, `DropZoneCard`, `StickerTile`, `SoftCard`, `PastelChip`, `PillButton`, `StarRating`, `CutoutImage`.
- CaptureFeature store API (unchanged): `store.isProcessing`, `store.candidates: [CutoutCandidate]` (`id`, `pngData: Data`, `isSelected: Bool`), `store.send(.toggleCandidate(id))`, `store.chosenPlace?.name`, `store.send(.choosePlaceTapped)`, `store.memo` / `.memoChanged(String)`, `store.rating: Int?` / `.ratingChanged(Int?)`, `store.send(.saveTapped)`, `$store.scope(state: \.placePicker, action: \.placePicker)`, `store.send(.photoPicked(Data))`.
- PlacePickerFeature store API (unchanged): `store.places: [PlaceInfo]` (`id`, `name`, `address`), `store.send(.placeSelected(place))`, `store.selected?.id`, `store.manualName` / `.manualNameChanged(String)`, `store.send(.useManualEntry)`, `store.isLoading`, `store.send(.task)`.

- [ ] **Step 1: Replace `CaptureView.swift`**

```swift
import SwiftUI
import PhotosUI
import ComposableArchitecture

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItem: PhotosPickerItem?
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    private let candidateColumns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        NavigationStack {
            ScreenScaffold(title: "한 끼 담기", doodle: nil) {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        DropZoneCard { Label("음식 사진 고르기", systemImage: "camera") }
                    }
                    .buttonStyle(.plain)

                    if store.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.appBlue)
                            Text("음식 누끼 따는 중…").font(.appBody).foregroundStyle(.appMuted)
                        }
                    }

                    if !store.candidates.isEmpty {
                        Text("담을 누끼 고르기").font(.appSection).foregroundStyle(.appInk)
                        LazyVGrid(columns: candidateColumns, spacing: 10) {
                            ForEach(Array(store.candidates.enumerated()), id: \.element.id) { index, candidate in
                                Button { store.send(.toggleCandidate(candidate.id)) } label: {
                                    StickerTile(tint: .rotating(index)) {
                                        CutoutImage(data: candidate.pngData)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(candidate.isSelected ? Color.appBlue : Color.appMuted)
                                            .padding(6)
                                    }
                                    .opacity(candidate.isSelected ? 1 : 0.5)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        SoftCard {
                            VStack(spacing: 12) {
                                Button { store.send(.choosePlaceTapped) } label: {
                                    HStack {
                                        Text("식당").font(.appSection).foregroundStyle(.appInk)
                                        Spacer()
                                        PastelChip(store.chosenPlace?.name ?? "선택 안 함",
                                                   glyph: "✦", tone: .blue)
                                    }
                                }
                                .buttonStyle(.plain)
                                Divider()
                                HStack {
                                    Text("메모").font(.appSection).foregroundStyle(.appInk)
                                    Spacer()
                                    TextField("한 줄 남기기", text: Binding(
                                        get: { store.memo },
                                        set: { store.send(.memoChanged($0)) }
                                    ))
                                    .font(.appBody)
                                    .multilineTextAlignment(.trailing)
                                }
                                Divider()
                                HStack {
                                    Text("별점").font(.appSection).foregroundStyle(.appInk)
                                    Spacer()
                                    StarRating(rating: store.rating,
                                               onChange: { store.send(.ratingChanged($0)) })
                                }
                            }
                        }

                        PillButton("다이어리에 저장 ♡",
                                   enabled: store.candidates.contains(where: \.isSelected)) {
                            store.send(.saveTapped)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

- [ ] **Step 2: Replace `PlacePickerView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct PlacePickerView: View {
    @Bindable var store: StoreOf<PlacePickerFeature>
    public init(store: StoreOf<PlacePickerFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("근처 식당").font(.appSection).foregroundStyle(.appMuted)
                    VStack(spacing: 10) {
                        ForEach(store.places) { place in
                            Button { store.send(.placeSelected(place)) } label: {
                                SoftCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.name).font(.appSection).foregroundStyle(.appInk)
                                            Text(place.address).font(.appCaption).foregroundStyle(.appMuted)
                                        }
                                        Spacer()
                                        if store.selected?.id == place.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appBlue)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("직접 입력").font(.appSection).foregroundStyle(.appMuted).padding(.top, 4)
                    SoftCard {
                        TextField("식당 이름", text: Binding(
                            get: { store.manualName },
                            set: { store.send(.manualNameChanged($0)) }
                        ))
                        .font(.appBody)
                    }
                    PillButton("이 이름으로 사용", enabled: !store.manualName.isEmpty) {
                        store.send(.useManualEntry)
                    }
                }
                .padding(18)
            }
            if store.isLoading { ProgressView().tint(.appBlue) }
        }
        .navigationTitle("식당 선택")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.task) }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 4: Commit**

```bash
git add Sources/FeatureKit/Capture/CaptureView.swift Sources/FeatureKit/Capture/PlacePickerView.swift
git commit -m "feat(design): reskin CaptureView + PlacePickerView (pastel)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Reskin MealDetailView

**Files:**
- Modify (full replace): `Sources/FeatureKit/MealDetail/MealDetailView.swift`

**Interfaces:**
- Consumes: `SoftCard`, `PastelChip`, `StarRating`, `StickerTile`, `StickerTint`, `CutoutImage`.
- Store API (unchanged): `store.meal: MealSnapshot?` (`place: PlaceInfo?`, `eatenAt: Date`, `rating: Int?`, `memo: String`, `cutouts: [CutoutSnapshot]`), `store.send(.deleteTapped)`, `store.send(.task)`. Keep the existing delete confirmation dialog. This view is pushed in a `NavigationStack`, so keep the navigation bar (back button) — style it milk.

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI
import ComposableArchitecture

public struct MealDetailView: View {
    @Bindable var store: StoreOf<MealDetailFeature>
    @State private var confirmingDelete = false
    public init(store: StoreOf<MealDetailFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                if let meal = store.meal {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(meal.place?.name ?? "한 끼 기록")
                            .font(.appDisplay).foregroundStyle(.appInk)

                        HStack(spacing: 8) {
                            PastelChip(meal.eatenAt.formatted(.dateTime.month().day().weekday()),
                                       glyph: "📅", tone: .pink)
                            if meal.rating != nil { StarRating(rating: meal.rating) }
                        }

                        if !meal.memo.isEmpty {
                            SoftCard {
                                Text(meal.memo).font(.appBody).foregroundStyle(.appInk)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(meal.cutouts.enumerated()), id: \.element.id) { index, cutout in
                                StickerTile(tint: .rotating(index)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView().tint(.appBlue).padding(.top, 80)
                }
            }
        }
        .navigationTitle("한 끼 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appMilk, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("삭제") { confirmingDelete = true }
                    .foregroundStyle(Color.appPinkInk)
            }
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { store.send(.deleteTapped) }
            Button("취소", role: .cancel) {}
        }
        .task { store.send(.task) }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/MealDetail/MealDetailView.swift
git commit -m "feat(design): reskin MealDetailView (pastel)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Floating tab bar + light-mode root + full verification

**Files:**
- Create: `Sources/FeatureKit/Root/FloatingTabBar.swift`
- Modify (full replace): `Sources/FeatureKit/Root/RootView.swift`
- Modify: `Sources/FoodDiary/FoodDiaryApp.swift` (add `.preferredColorScheme(.light)`)

**Interfaces:**
- Consumes: tokens/components; `RootFeature.Tab` (`.collection`, `.capture`), `store.tab`, `store.send(.tabChanged(_:))`, `$store.scope(state: \.path, action: \.path)`, `store.scope(state: \.collection, action: \.collection)`, `store.scope(state: \.capture, action: \.capture)`.
- Produces: `FloatingTabBar(selected: RootFeature.Tab, onSelect: (RootFeature.Tab) -> Void)`.
- Note: RootView switches to a `ZStack` (content + overlaid floating bar) driven by `store.tab`, replacing the system `TabView`, so the bar matches the design. The collection tab keeps its `NavigationStack` for meal-detail push. Behavior (which tab shows, navigation, tab switching) is unchanged.

- [ ] **Step 1: Write `FloatingTabBar.swift`**

```swift
import SwiftUI

public struct FloatingTabBar: View {
    private let selected: RootFeature.Tab
    private let onSelect: (RootFeature.Tab) -> Void

    public init(selected: RootFeature.Tab, onSelect: @escaping (RootFeature.Tab) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 4) {
            item(.collection, systemImage: "square.grid.2x2.fill", title: "컬렉션")
            item(.capture, systemImage: "plus.circle.fill", title: "담기")
        }
        .padding(6)
        .background(Color.appCard)
        .clipShape(Capsule())
        .softShadow()
        .padding(.horizontal, 60)
        .padding(.bottom, 6)
    }

    private func item(_ tab: RootFeature.Tab, systemImage: String, title: String) -> some View {
        let active = selected == tab
        return Button { onSelect(tab) } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.appCaption)
            .foregroundStyle(active ? Color.appBlueInk : Color.appMuted)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(active ? Color.appTileBlue : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Replace `RootView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>
    public init(store: StoreOf<RootFeature>) { self.store = store }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.appMilk.ignoresSafeArea()

            switch store.tab {
            case .collection:
                NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                    CollectionView(store: store.scope(state: \.collection, action: \.collection))
                } destination: { detailStore in
                    MealDetailView(store: detailStore)
                }
            case .capture:
                CaptureView(store: store.scope(state: \.capture, action: \.capture))
            }

            FloatingTabBar(selected: store.tab) { store.send(.tabChanged($0)) }
        }
    }
}
```

- [ ] **Step 3: Add light mode to the app root**

In `Sources/FoodDiary/FoodDiaryApp.swift`, change the scene body so the root view is pinned to light mode:
```swift
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.light)
        }
    }
```
(Only add the `.preferredColorScheme(.light)` modifier — leave the rest of the file, including the `store` setup, unchanged.)

- [ ] **Step 4: Build app + regression test the reducers**

Run: `tuist generate --no-open && tuist build FeatureKit`
Then the app: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' 2>&1 | tail -3`
Then the existing suite (must still pass — no reducer changes): `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=SIMID' 2>&1 | tail -5`
Expected: `Build Succeeded` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Visual verification in the simulator**

Build for a booted simulator, install, launch, and screenshot the Collection (empty) and Capture screens; confirm the pastel look and the floating tab bar switch. (The controller drives the simulator tools; a clean build + the two screenshots are the bar.)

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Root/FloatingTabBar.swift Sources/FeatureKit/Root/RootView.swift Sources/FoodDiary/FoodDiaryApp.swift
git commit -m "feat(design): floating pastel tab bar + light-mode root

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 tokens** → Task 1 (color/font/style). ✅
- **Spec §4 components** → Task 2 (StickerTile/SoftCard/PastelChip/PillButton/StarRating), Task 3 (ScreenScaffold/DropZoneCard/EmptyState), Task 7 (FloatingTabBar). ✅
- **Spec §5.1 Collection** → Task 4. §5.2 Capture+PlacePicker → Task 5. §5.3 MealDetail → Task 6. ✅
- **Spec §2 light-mode root** → Task 7 Step 3. **View-layer only** → no task touches a `*Feature.swift`, client, model, or test assertion; the only test added (Task 1) covers new design-system code. ✅
- **Spec §7 testing** → existing suite re-run in Task 7 Step 4; simulator screenshots in Step 5. ✅
- **Type consistency:** every store property/action used in Tasks 4–7 matches the current reducers (verified against the real view files): `cutouts`, `isLoading`, `cutoutTapped`, `onAppear`, `candidates`/`toggleCandidate`, `chosenPlace`, `choosePlaceTapped`, `memo`/`memoChanged`, `rating`/`ratingChanged`, `saveTapped`, `placePicker` scope, `photoPicked`, `places`/`placeSelected`/`selected`/`manualName`/`manualNameChanged`/`useManualEntry`, `meal`/`deleteTapped`/`task`, `tab`/`tabChanged`, `path` scope.

## Notes for the implementer

- `-destination 'id=SIMID'` needs a booted simulator UDID: `xcrun simctl list devices booted` (or boot one). For pure build steps, `generic/platform=iOS Simulator` is fine.
- Everything is SwiftUI presentation; if a specific modifier name differs on this SDK, adapt to the current spelling — the visual result and the unchanged store bindings are the contract.
- Do not convert `CutoutImage`, any `*Feature.swift`, or tests. If a reskin seems to require a reducer change, stop and report — it shouldn't.
