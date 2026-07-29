import SwiftUI
import ComposableArchitecture
import Models
import ClientKit

/// Online voting World Cup UI: renders `GroupDeciderFeature`'s phase machine
/// (start → lobby → voting → reveal → champion) with a countdown ring and a
/// tally reveal. View-only — it never mutates state beyond sending the
/// reducer's existing actions.
public struct GroupDeciderView: View {
    @Bindable var store: StoreOf<GroupDeciderFeature>
    public init(store: StoreOf<GroupDeciderFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        ZStack {
            PaperBackground()
            switch store.phase {
            case .idle, .authenticating, .matchmaking:
                startScreen
            case .lobby:
                lobby
            case .voting:
                votingScreen
            case .reveal:
                revealScreen
            case .champion:
                championScreen
            }

            VStack(spacing: 0) {
                CoverBar("함께 월드컵") { store.send(.leave) }
                Spacer(minLength: 0)
            }
            .zIndex(10)
        }
        .task { store.send(.onAppear) }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 18) {
            Text(L10n.text("group.start.title")).font(.appDisplay).foregroundStyle(.appInk)
            Text(L10n.text("group.start.subtitle"))
                .font(.appBody).foregroundStyle(.appMuted).multilineTextAlignment(.center)
            if let err = store.errorText {
                Text(err).font(.appCaption).foregroundStyle(.appPinkInk)
            }
            if store.phase == .idle {
                PillButton("게임센터로 시작") { store.send(.startTapped) }.padding(.horizontal, 60)
            } else {
                ProgressView().tint(.appBlue)
            }
        }
        .padding(24)
    }

    // MARK: - Lobby

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("메뉴 고르기").font(.appTitle).foregroundStyle(.appInk)
            Text(L10n.format("group.lobby.progress", store.allPlayerIDs.count, store.menus.count))
                .font(.appCaption).foregroundStyle(.appMuted)
            if store.mySubmitted {
                Text("제출 완료! 다른 사람들을 기다리는 중… ⏳")
                    .font(.appBody).foregroundStyle(.appBlueInk)
            } else {
                Text("내 누끼에서 먹고 싶은 메뉴를 골라요").font(.appBody).foregroundStyle(.appMuted)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.myCutouts) { c in
                            Button { store.send(.cutoutPicked(c)) } label: {
                                StickerTile(tint: .rotating(c.id.hashValue)) { CutoutImage(fileName: c.fileName) }
                            }
                            .buttonStyle(KitschPressStyle())
                        }
                    }
                }
            }
        }
        .padding(24)
    }

    // MARK: - Voting

    private var roundLabel: String {
        store.round.count <= 2 ? L10n.text("결승") : L10n.format("round.count", store.round.count)
    }

    private var votingScreen: some View {
        VStack(spacing: 20) {
            Text(roundLabel).font(.appDisplay).foregroundStyle(.appInk)
            countdownRing
            if let pair = store.currentPair {
                HStack(spacing: 16) {
                    candidateCard(pair.0)
                    candidateCard(pair.1)
                }
            }
            Text(L10n.format("group.voting.progress", store.votes.count, store.allPlayerIDs.count))
                .font(.appCaption).foregroundStyle(.appMuted)
        }
        .padding(24)
    }

    private var countdownRing: some View {
        ZStack {
            Circle().stroke(Color.appCherry.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(store.secondsLeft) / 5)
                .stroke(Color.appCherry, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: store.secondsLeft)
            Text("\(store.secondsLeft)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.appCherry)
        }
        .frame(width: 56, height: 56)
    }

    private func candidateCard(_ candidate: MenuPick) -> some View {
        let isSelected = store.myVote == candidate.playerID
        let hasVoted = store.myVote != nil
        return Button {
            store.send(.voteTapped(candidate.playerID))
        } label: {
            VStack(spacing: 10) {
                StickerTile(tint: .pink) { CutoutImage(data: candidate.thumbnail, cacheKey: candidate.playerID) }
                    .frame(width: 140, height: 140)
                    .overlay {
                        if isSelected {
                            Circle().stroke(Color.appCherry, lineWidth: 4).padding(-4)
                        }
                    }
                candidateLabel(candidate)
            }
            .padding(10)
            .opacity(hasVoted && !isSelected ? 0.4 : 1)
        }
        .buttonStyle(KitschPressStyle())
        .disabled(hasVoted)
    }

    private func candidateLabel(_ candidate: MenuPick) -> some View {
        VStack(spacing: 2) {
            Text(candidate.placeName.isEmpty ? candidate.playerName : candidate.placeName)
                .font(.appSection).foregroundStyle(.appInk).lineLimit(1)
            if !candidate.tags.isEmpty {
                TagChipRow(candidate.tags, limit: 2)
            }
        }
    }

    // MARK: - Reveal

    private var revealScreen: some View {
        VStack(spacing: 20) {
            Text(roundLabel).font(.appDisplay).foregroundStyle(.appInk)
            if let pair = store.currentPair, let tally = store.lastTally {
                HStack(spacing: 16) {
                    revealCard(pair.0, votes: tally.left, isWinner: tally.winner == pair.0.playerID)
                    revealCard(pair.1, votes: tally.right, isWinner: tally.winner == pair.1.playerID)
                }
            } else if let tally = store.lastTally, let bye = store.menus[tally.winner] {
                // Odd bracket sizes fold in an automatic bye: only one candidate this round.
                revealCard(bye, votes: 0, isWinner: true)
            }
        }
        .padding(24)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: store.lastTally)
    }

    private func revealCard(_ candidate: MenuPick, votes: Int, isWinner: Bool) -> some View {
        ZStack {
            VStack(spacing: 10) {
                StickerTile(tint: isWinner ? .pink : .plain) {
                    CutoutImage(data: candidate.thumbnail, cacheKey: candidate.playerID)
                }
                .frame(width: 140, height: 140)
                candidateLabel(candidate)
                Text("\(votes)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.appCherry)
            }
            if isWinner {
                ConfettiBurst().frame(width: 160, height: 160).offset(y: -60)
            }
        }
        .scaleEffect(isWinner ? 1.08 : 0.92)
        .opacity(isWinner ? 1 : 0.6)
    }

    // MARK: - Champion

    private var championScreen: some View {
        ZStack {
            ConfettiBurst().frame(width: 260, height: 260).offset(y: -60)
            VStack(spacing: 16) {
                if let w = store.championPick {
                    StickerTile(tint: .pink) { CutoutImage(data: w.thumbnail, cacheKey: w.playerID) }
                        .frame(width: 200, height: 200)
                    Text(L10n.format(
                        "group.champion.title",
                        w.playerName,
                        w.placeName.isEmpty ? L10n.text("이 메뉴") : w.placeName
                    ))
                    .font(.appDisplay).foregroundStyle(.appBlueInk).multilineTextAlignment(.center)
                    if !w.tags.isEmpty {
                        TagChipRow(w.tags, limit: 3, size: .regular)
                    }
                }
            }
            .padding(24)
        }
    }

}
