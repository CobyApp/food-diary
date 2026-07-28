# 월드컵 단일화 + 온라인 투표 월드컵 — Design Spec

- **Date:** 2026-07-27
- **Scope:** Cut the game surface down to **World Cup only** (solo), and rebuild the
  online mode as a **timed voting World Cup**: everyone votes on the same pair
  within 5 seconds, the majority advances, until a champion.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Why

Four solo games (가챠 / 룰렛 / 카드 / 월드컵) diluted the app: each was shallow, and
the hub needed a grid + lock badges to hold them. One well-made game reads as
intentional. World Cup is the best fit — it's the only one where the *user's taste*
decides, and it maps naturally onto multiplayer voting.

## 2. Solo: World Cup only

- **Delete** `GachaFeature/View`, `RouletteFeature/View`, `CardFlipFeature/View`
  and their test files.
- `GameKind` collapses to a single case (or is removed). The hub stops being a
  grid: the 뭐먹지 tab becomes **two entries**:
  - **혼자 월드컵** (`WorldCupFeature`, unchanged) — needs ≥ 2 cutouts
  - **함께 월드컵** (online) — the group entry
- `GameDestination` enum drops to the single `worldCup` case (keep the enum so the
  presentation plumbing and its test stay shaped the same).
- `RandomClient` stays (World Cup shuffles the bracket with it).

## 3. Online: timed voting World Cup

### Flow
1. **Match** (unchanged): Game Center authenticate → matchmake → lobby.
2. **Submit** (unchanged): each player picks one cutout from their own collection;
   the app sends `MenuPick` (thumbnail + memo + place). Those picks are the
   candidates.
3. **Bracket** (host): once every known player has submitted, the host orders the
   candidates with `RandomClient.shuffled`-equivalent determinism and broadcasts
   the order, then announces match 1.
4. **Voting round**: everyone sees the same pair with a **5-second countdown**.
   Tapping a side sends `.vote(candidateID)`. When the timer expires the host
   tallies:
   - more votes wins;
   - **tie or nobody voted** → the candidate that appears earlier in the broadcast
     bracket order wins (deterministic, no coin flip needed);
   - the host broadcasts the round result (winner + both vote counts) so every
     client shows the same tally reveal.
5. Winners advance; **odd counts get a bye** (last candidate advances without a
   match). Repeat until one remains → **champion**, shown with whose menu it was.

### Protocol additions (`MultiplayerMessage`)
- `.bracket([String])` — candidate order (playerIDs) from the host
- `.pair(index: Int)` — host announces which match is live
- `.vote(candidateID: String)` — a player's vote for the live match
- `.roundResult(winnerID: String, leftVotes: Int, rightVotes: Int)`
- `.champion(String)`
(existing `.menu(MenuPick)` stays; `.result(winnerPlayerID:)` is replaced by
`.champion` — the old case is removed.)

### Timing
The countdown uses `@Dependency(\.continuousClock)` so tests drive it with a
`TestClock` (no wall-clock flakiness). 5 seconds per match, and the reveal holds
~1.5 s before the next pair.

### Host authority
Only the host tallies and advances (host = lexicographically smallest player id,
as today). Clients render what they're told, so no client can desync the bracket.

## 4. Constraints

- `WorldCupFeature` (solo) is **unchanged** — its tests keep passing untouched.
- `GroupDeciderFeature` is rewritten for voting; its tests are rewritten with a
  `TestClock` + mock `MultiplayerClient`.
- GameKit real-time still cannot be exercised in the simulator: the reducer is the
  tested brain, the live adapter stays compile-verified, and real matches are
  device-verified by the user (2+ devices).
- Existing pastel/kitsch DesignSystem components only; Korean UI + `L10n` (new copy
  added to all four `.lproj` files); iOS 18; Swift 6; TCA 1.26.
- `-skipMacroValidation`; no `tuist install`; no `Project.swift` edits.

## 5. Testing

- `GroupDeciderFeature` (mock multiplayer + `TestClock` + stubbed persistence):
  - all players submitted → host broadcasts bracket + first pair;
  - a vote is recorded and sent;
  - clock advances 5 s → host tallies, majority wins, `roundResult` broadcast;
  - tie → earlier-in-bracket candidate wins;
  - final match → `champion` set on host and on a non-host receiving `.champion`.
- Hub tests updated for the two-entry layout.
- Deleted games' tests are removed with their features.
- Full suite green; views build-verified; online feel device-verified.

## 6. Out of Scope

Spectators; rejoin after disconnect (still returns to lobby); more than one vote
per player per match; score/leaderboards; changing the solo World Cup's rules.
