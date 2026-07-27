# 함께 정하기 (Game Center Group Decider) — Design Spec

- **Date:** 2026-07-25
- **Scope:** A Game Center (GameKit) multiplayer decider: friends match up, each
  submits a menu from their own cutouts (with its one-line memo + restaurant), and
  a synchronized roulette picks the group's meal. Roadmap bonus feature.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept & honest constraints

Multiple people join a Game Center match; each picks one food cutout from their
collection; the app bundles that cutout's **thumbnail + 한줄평(memo) + 가게(이름·주소)**
and shares it; when everyone has submitted, the host runs a synchronized roulette
and all players see the same winner: "오늘은 ○○님의 [가게] — *한줄평* 🍜".

**Reality (agreed):** GameKit real-time multiplayer **cannot be verified in the
simulator** — it needs 2+ real devices signed into Game Center. This build
delivers: (a) a fully **TestStore-tested reducer** driving the flow via a mock
`MultiplayerClient`, and (b) a **compile-verified GameKit live adapter**. Real
match behavior must be verified on device by the user. The user must also enable
**Game Center for the app in App Store Connect**; the code adds the entitlement.

## 2. Global Constraints

- New `MultiplayerClient` (GameKit) + a new FeatureKit `Group/` feature; entry from
  the existing GameHub (a 5th card). Does not change other reducers' logic.
- Randomness only via `RandomClient` (host's winner pick) → testable.
- Pastel DesignSystem; light mode; Korean UI strings; iOS 18; Swift 6; TCA 1.26.
- Always `-skipMacroValidation`; never `tuist install`. `Project.swift` IS edited
  (add the Game Center entitlement to the app target) — this is the one allowed
  Project.swift change for this feature.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Data / message protocol

- **`MenuPick`** (Codable, Sendable): `playerID: String`, `playerName: String`,
  `thumbnail: Data` (a ~150px JPEG of the cutout, compressed to stay under the
  GKMatch per-message limit), `memo: String`, `placeName: String`, `address: String`.
  Built when a player picks a cutout: resolve the cutout's meal via
  `persistence.mealByCutout(id)` → `memo` + `place.name`/`place.address`; downscale
  the cutout PNG (loaded from disk) to the thumbnail JPEG.
- **`MultiplayerMessage`** (Codable, Sendable): `.menu(MenuPick)` |
  `.result(winnerPlayerID: String)`.
- **`RemotePlayer`**: `id: String`, `displayName: String`. **`LocalPlayer`**:
  `id`, `displayName`.
- **`MultiplayerEvent`**: `.playersChanged([RemotePlayer])` |
  `.received(MultiplayerMessage, from: String)` | `.matchEnded`.

## 4. `MultiplayerClient` (fully encapsulates GameKit)

`@DependencyClient struct MultiplayerClient: Sendable`:
- `authenticate: @Sendable () async throws -> LocalPlayer`
- `startMatch: @Sendable () async throws -> Void` — live impl presents
  `GKMatchmakerViewController` (finds the key window's root VC) and resolves when a
  match forms; throws on cancel/failure.
- `events: @Sendable () -> AsyncStream<MultiplayerEvent>` — live impl bridges
  `GKMatchDelegate` callbacks.
- `send: @Sendable (MultiplayerMessage) async throws -> Void` — `match.sendData(toAllPlayers:)`.
- `disconnect: @Sendable () -> Void`.
- `liveValue` = GameKit; `testValue`/`previewValue` = deterministic stubs.
  `DependencyValues.multiplayer`.

The reducer never touches GameKit types — only the client interface — so it is
fully mockable.

## 5. `GroupDeciderFeature` (the tested brain)

- `@ObservableState State`: `phase: Phase` (`idle`/`authenticating`/`matchmaking`/
  `lobby`/`result`), `localPlayer: LocalPlayer?`, `players: [RemotePlayer]`,
  `menus: [String: MenuPick]` (playerID→pick), `myCutouts: [CutoutSnapshot]`,
  `winner: MenuPick?`, `errorText: String?`. Computed `isHost` = `localPlayer.id ==
  allPlayerIDs.min()` (deterministic host convention); `allSubmitted` = every known
  player has a menu.
- `Action`: `onAppear` (load `myCutouts`), `startTapped`, `authenticated(LocalPlayer)`,
  `matchStarted`, `eventReceived(MultiplayerEvent)`, `cutoutPicked(CutoutSnapshot)`,
  `menuBuilt(MenuPick)`, `resultResolved(MenuPick?)`, `leave`, `failed(String)`.
- Flow: `startTapped` → `.run` authenticate → `authenticated` → `.run` startMatch →
  `matchStarted` (phase `.lobby`) + start forwarding `multiplayer.events()` into
  `eventReceived`. `cutoutPicked` → `.run` builds `MenuPick` (thumbnail + memo +
  place) → `menuBuilt` → store in `menus[me]` + `.run` send `.menu(pick)`.
  `eventReceived(.received(.menu(p), _))` → store `menus[p.playerID]`.
  `eventReceived(.playersChanged(list))` → update `players`. When `allSubmitted` &&
  `isHost` → host picks a winner via `random.pick(Array(menus.values))` → send
  `.result(winnerID)` → set `winner`. `eventReceived(.received(.result(id), _))` →
  set `winner = menus[id]` (phase `.result`).
- **Testable via mock `MultiplayerClient`**: tests send `.eventReceived(...)`
  directly (bypassing the live AsyncStream) to drive players joining, menus
  arriving, host winner selection, and result reception.

## 6. Views

- `GroupDeciderView`: phase-driven — a start screen ("함께 정하기 🎉" + 게임센터 안내
  + 시작 버튼), a lobby (player list + who submitted + a cutout picker grid from
  `myCutouts`), and a result card (winner's thumbnail + "○○님의 [가게]" + 한줄평).
  Matchmaking is presented by the live client (no dedicated SwiftUI screen).
- **Entry:** `GameHubFeature` gains `@Presents var groupDecider:
  GroupDeciderFeature.State?` + a `groupTapped` action + `.ifLet`; `GameHubView`
  adds a "함께 정하기 🎉" card and a `fullScreenCover` for it. (Separate from the
  existing 4-game `game` destination.)

## 7. Entitlement

`Project.swift` app target gains `entitlements: .dictionary(["com.apple.developer.game-center": true])`.
(App Store Connect Game Center enablement is a manual step for the user.)

## 8. Testing

- `GroupDeciderFeature` reducer (mock `MultiplayerClient` + injected `random` +
  stubbed `persistence`): auth→lobby transition; `cutoutPicked` builds a `MenuPick`
  with memo+place and sends it; two players submitting → host selects the injected
  winner and broadcasts `.result`; a non-host `resultResolved` on `.result`.
- `MenuPick`/`MultiplayerMessage` Codable round-trip unit test.
- Views + GameKit live adapter: build-verified only (device testing by the user).

## 9. Out of Scope

More than roulette; reconnection/late-join handling beyond returning to lobby;
spectator mode; persisting group results; cross-region matchmaking tuning.
