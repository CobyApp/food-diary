import SwiftUI
import ComposableArchitecture
import Models
import ClientKit

public struct GroupDeciderView: View {
    @Bindable var store: StoreOf<GroupDeciderFeature>
    public init(store: StoreOf<GroupDeciderFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            switch store.phase {
            case .idle, .authenticating, .matchmaking:
                startScreen
            case .lobby:
                lobby
            case .voting, .reveal:
                // NOTE: placeholder voting UI only, kept just compiling for Task 2
                // (protocol + reducer). The real timed-voting bracket UI is Task 3.
                votingPlaceholder
            case .champion:
                resultScreen
            }
            closeButton
        }
        .task { store.send(.onAppear) }
    }

    private var startScreen: some View {
        VStack(spacing: 18) {
            Text("함께 정하기 🎉").font(.appDisplay).foregroundStyle(.appInk)
            Text("친구를 초대해서 다 같이\n오늘 뭐 먹을지 정해요")
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

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("메뉴 고르기").font(.appTitle).foregroundStyle(.appInk)
            Text("참가자 \(store.allPlayerIDs.count)명 · 제출 \(store.menus.count)명")
                .font(.appCaption).foregroundStyle(.appMuted)
            if store.mySubmitted {
                Text("제출 완료! 다른 사람들을 기다리는 중… ⏳").font(.appBody).foregroundStyle(.appBlueInk)
            } else {
                Text("내 누끼에서 먹고 싶은 메뉴를 골라요").font(.appBody).foregroundStyle(.appMuted)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.myCutouts) { c in
                            Button { store.send(.cutoutPicked(c)) } label: {
                                StickerTile(tint: .rotating(c.id.hashValue)) { CutoutImage(fileName: c.fileName) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
    }

    // NOTE: placeholder voting UI only — kept just enough to compile for Task 2
    // (protocol + reducer rewrite). The real timed-voting bracket UI is Task 3.
    private var votingPlaceholder: some View {
        VStack(spacing: 16) {
            Text("투표 중… (\(store.secondsLeft)초)").font(.appTitle).foregroundStyle(.appInk)
            if let pair = store.currentPair {
                HStack(spacing: 16) {
                    votingCandidate(pair.0)
                    votingCandidate(pair.1)
                }
            }
            if let tally = store.lastTally {
                Text("결과: \(tally.winner) (\(tally.left) : \(tally.right))")
                    .font(.appBody).foregroundStyle(.appMuted)
            }
        }
        .padding(24)
    }

    private func votingCandidate(_ candidate: MenuPick) -> some View {
        Button { store.send(.voteTapped(candidate.playerID)) } label: {
            VStack(spacing: 8) {
                StickerTile(tint: .pink) { CutoutImage(data: candidate.thumbnail) }
                    .frame(width: 140, height: 140)
                Text(candidate.placeName.isEmpty ? candidate.playerName : candidate.placeName)
                    .font(.appCaption).foregroundStyle(.appInk)
            }
        }
        .buttonStyle(.plain)
        .opacity(store.myVote == nil || store.myVote == candidate.playerID ? 1 : 0.4)
    }

    private var resultScreen: some View {
        VStack(spacing: 16) {
            Text("오늘의 선택 🎉").font(.appTitle).foregroundStyle(.appInk)
            if let w = store.championPick {
                StickerTile(tint: .pink) { CutoutImage(data: w.thumbnail) }
                    .frame(width: 200, height: 200)
                Text("\(w.playerName)님의 \(w.placeName.isEmpty ? "메뉴" : w.placeName)")
                    .font(.appDisplay).foregroundStyle(.appBlueInk).multilineTextAlignment(.center)
                if !w.memo.isEmpty {
                    Text("\u{201C}\(w.memo)\u{201D}").font(.appBody).foregroundStyle(.appInk)
                }
                if !w.address.isEmpty {
                    Text(w.address).font(.appCaption).foregroundStyle(.appMuted)
                }
            }
            PillButton("나가기") { store.send(.leave) }.padding(.horizontal, 60)
        }
        .padding(24)
    }

    private var closeButton: some View {
        Button { store.send(.leave) } label: {
            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.appMuted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(20)
    }
}
