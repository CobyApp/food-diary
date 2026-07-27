import SwiftUI
import ComposableArchitecture
import Models

public struct GachaView: View {
    @Bindable var store: StoreOf<GachaFeature>
    @State private var revealResult = false
    @State private var drumTurns = 0.0
    @State private var drumShake: CGFloat = 0        // quick lateral jitter on lever pull
    @State private var capsuleDrop: CGFloat = -140   // y offset of the dispensed capsule
    @State private var capsuleOpen = false
    @State private var capsuleSquash: CGFloat = 1    // landing squash-and-stretch factor
    @State private var knobTurn: Double = 0          // knob rotation, driven by the drag
    @State private var knobDragAngle: Double?        // last touch angle while dragging
    @State private var knobTurned: Double = 0        // accumulated turn of the current drag
    @State private var knobDetents = 0               // bumps every 30 degrees for a click
    public init(store: StoreOf<GachaFeature>) { self.store = store }

    /// Turning this far dispenses a capsule.
    private let knobThreshold: Double = 120
    private let knobSize: CGFloat = 92

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(cutout: result, info: store.resultInfo,
                           onAgain: {
                               capsuleDrop = -140
                               capsuleOpen = false
                               capsuleSquash = 1
                               resetKnob()
                               store.send(.playAgain)
                           },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    gameHeader("캡슐 뽑기", subtitle: "손잡이를 돌려 오늘의 한 끼를 꺼내요")
                    Spacer()
                    capsuleMachine
                    Text(L10n.text(store.isSpinning ? "캡슐 섞는 중" : "손잡이를 돌려보세요"))
                        .font(.appBody).foregroundStyle(.appMuted)
                        .contentTransition(.opacity)
                    Spacer()
                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(24)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: revealResult)
        .task(id: store.result?.id) {
            guard store.result != nil else {
                revealResult = false
                capsuleDrop = -140
                capsuleOpen = false
                capsuleSquash = 1
                resetKnob()
                return
            }
            // 1) capsule falls into the tray
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 12)) { capsuleDrop = 26 }
            try? await Task.sleep(for: .milliseconds(520))
            // squash-and-stretch bounce as the capsule lands
            withAnimation(.easeOut(duration: 0.09)) { capsuleSquash = 0.86 }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 12)) { capsuleSquash = 1 }
            // 2) it splits open, revealing the cutout
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { capsuleOpen = true }
            try? await Task.sleep(for: .milliseconds(700))
            // 3) hand off to the result card
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { revealResult = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.isSpinning)
    }

    private var capsuleMachine: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.appBlue.opacity(0.32))
                    Circle().stroke(Color.appChocolate, lineWidth: 4)
                    ForEach(Array(store.cutouts.prefix(5).enumerated()), id: \.element.id) { index, cutout in
                        capsule(index: index, cutout: cutout)
                    }
                }
                .frame(width: 208, height: 208)
                .rotationEffect(.degrees(drumTurns * 360))
                .clipped()
                .offset(x: drumShake)
                .overlay {
                    // Glass dome: a crisp highlight arc plus a soft top-left sheen.
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0)],
                                    center: UnitPoint(x: 0.32, y: 0.26),
                                    startRadius: 2,
                                    endRadius: 132
                                )
                            )
                        Circle()
                            .trim(from: 0.56, to: 0.72)
                            .stroke(
                                Color.white.opacity(0.85),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .padding(16)
                            .blur(radius: 1.5)
                    }
                    .allowsHitTesting(false)
                }

                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.appPink)
                    .frame(width: 246, height: 178)
                    .overlay {
                        VStack(spacing: 8) {
                            // Coin slot on the plate's top edge.
                            Capsule()
                                .fill(Color.appChocolate.opacity(0.85))
                                .frame(width: 46, height: 10)
                                .overlay {
                                    Capsule().strokeBorder(Color.appChocolate, lineWidth: 1.5)
                                }
                            knob
                            // Outlet door the capsule drops out of.
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.appChocolate.opacity(0.55))
                                .frame(width: 84, height: 24)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(Color.appChocolate, lineWidth: 2)
                                }
                        }
                        .padding(.vertical, 10)
                    }
            }
        }
        .overlay(alignment: .top) { WashiTape(.appLavender).offset(y: -8) }
        .overlay(alignment: .bottom) {
            if let result = store.result, !revealResult { dispensedCapsule(result) }
        }
        .softShadow()
    }

    // MARK: - Knob

    /// A real gachapon knob: chrome bezel, domed metal body, chunky T-grip.
    /// Drag it around to turn; a full turn past the threshold dispenses a capsule.
    private var knob: some View {
        ZStack {
            // Static plate ring behind the knob, so the turn is readable against it.
            Circle()
                .fill(Color.appChocolate.opacity(0.16))
                .frame(width: knobSize + 12, height: knobSize + 12)

            // Rotating assembly: bezel + domed body + grip.
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color.appCard, Color.appMuted.opacity(0.55), Color.appCard,
                                Color.appMuted.opacity(0.7), Color.appCard,
                            ],
                            center: .center
                        )
                    )
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appCard, Color.appMilk, Color.appMuted.opacity(0.45)],
                            center: UnitPoint(x: 0.34, y: 0.3),
                            startRadius: 2,
                            endRadius: knobSize * 0.62
                        )
                    )
                    .padding(7)
                Circle()
                    .strokeBorder(Color.appChocolate, lineWidth: 3.5)

                // Chunky T-grip you can imagine pinching.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appChocolate, Color.appInk],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: knobSize * 0.66, height: 18)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.appCard.opacity(0.35))
                            .frame(height: 5)
                            .padding(.horizontal, 6)
                            .padding(.top, 2)
                    }
                    .softShadow()

                // Center screw.
                Circle().fill(Color.appMilk).frame(width: 12, height: 12)
                Circle().strokeBorder(Color.appChocolate.opacity(0.6), lineWidth: 2)
                    .frame(width: 12, height: 12)
            }
            .frame(width: knobSize, height: knobSize)
            .rotationEffect(.degrees(knobTurn))

            // Static cues: a 12 o'clock notch and a clockwise arrow hugging the bezel.
            Circle()
                .fill(Color.appCherry)
                .frame(width: 9, height: 9)
                .offset(y: -(knobSize / 2 + 9))
            // Clockwise cue arc, kept outside the bezel so it never overlaps the knob.
            Circle()
                .trim(from: 0.02, to: 0.20)
                .stroke(
                    Color.appCherry.opacity(0.7),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: knobSize + 28, height: knobSize + 28)
                .overlay(alignment: .bottom) {
                    Image(systemName: "arrowtriangle.left.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appCherry.opacity(0.7))
                        .offset(y: 5)
                }
        }
        .frame(width: knobSize + 30, height: knobSize + 30)
        .contentShape(Circle())
        .gesture(knobDrag)
        .onTapGesture { firePull() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.text("손잡이"))
        .accessibilityHint(L10n.text("손잡이를 돌려보세요"))
        .accessibilityAction { firePull() }
        .animation(.interpolatingSpring(stiffness: 150, damping: 11), value: knobTurn)
        .sensoryFeedback(.impact(weight: .light), trigger: knobDetents)
    }

    /// Turning the knob: accumulate the swept angle around its center.
    private var knobDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !store.isSpinning, store.result == nil else { return }
                let center = CGPoint(x: (knobSize + 30) / 2, y: (knobSize + 30) / 2)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                    * 180 / .pi
                defer { knobDragAngle = angle }
                guard let previous = knobDragAngle else { return }

                // Normalize the wraparound so a sweep across ±180 doesn't jump.
                var delta = angle - previous
                if delta > 180 { delta -= 360 }
                if delta < -180 { delta += 360 }

                knobTurn += delta
                knobTurned += abs(delta)
                knobDetents = Int(knobTurned / 30)
                if knobTurned >= knobThreshold { firePull() }
            }
            .onEnded { _ in
                knobDragAngle = nil
                guard store.result == nil, !store.isSpinning else { return }
                // Didn't turn far enough — spring back to rest.
                knobTurned = 0
                withAnimation(.interpolatingSpring(stiffness: 140, damping: 12)) { knobTurn = 0 }
            }
    }

    /// Dispense: spin the drum, finish the knob's turn, and let the reducer pick.
    private func firePull() {
        guard !store.isSpinning, store.result == nil else { return }
        knobDragAngle = nil
        knobTurned = 0
        withAnimation(.easeInOut(duration: 1.05)) { drumTurns += 4 }
        // Quick shake on the drum as the knob is turned.
        withAnimation(.easeInOut(duration: 0.09).repeatCount(4, autoreverses: true)) {
            drumShake = 5
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.36)) { drumShake = 0 }
        // Complete the revolution, then let it settle back.
        withAnimation(.easeOut(duration: 0.5)) { knobTurn += 360 - knobTurn.truncatingRemainder(dividingBy: 360) }
        store.send(.pullLever)
    }

    private func resetKnob() {
        knobTurn = 0
        knobTurned = 0
        knobDragAngle = nil
        knobDetents = 0
    }

    @ViewBuilder
    private func dispensedCapsule(_ cutout: CutoutSnapshot) -> some View {
        ZStack {
            // Two halves that part when the capsule opens.
            Circle()
                .fill(Color.appPink)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: -24))
                .offset(y: capsuleOpen ? -30 : 0)
            Circle()
                .fill(Color.appButter)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: 24))
                .offset(y: capsuleOpen ? 30 : 0)
            CutoutImage(fileName: cutout.fileName)
                .frame(width: 74, height: 74)
                .scaleEffect(capsuleOpen ? 1.15 : 0.6)
                .opacity(capsuleOpen ? 1 : 0)
        }
        .offset(y: capsuleDrop)
        .scaleEffect(x: 1 / capsuleSquash, y: capsuleSquash, anchor: .bottom)
        .overlay(alignment: .center) {
            // Sparkle burst radiating outward when the capsule opens.
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index) / 5 * 2 * .pi
                KitschSparkle()
                    .fill(Color.appButter)
                    .frame(width: 22, height: 22)
                    .offset(x: cos(angle) * 44, y: sin(angle) * 44)
                    .opacity(capsuleOpen ? 1 : 0)
                    .scaleEffect(capsuleOpen ? 1 : 0.2)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.04),
                        value: capsuleOpen
                    )
            }
        }
    }

    private func gameHeader(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text(L10n.text(title)).font(.appDisplay).foregroundStyle(.appInk)
            Text(L10n.text(subtitle)).font(.appBody).foregroundStyle(.appMuted)
        }
    }

    private func capsule(index: Int, cutout: CutoutSnapshot) -> some View {
        let angle = Double(index) * 1.25
        let x = CGFloat(cos(angle) * 62)
        let y = CGFloat(sin(angle) * 62)
        let colors: [Color] = [.appPink, .appButter, .appLavender]
        return Circle()
            .fill(colors[index % colors.count])
            .frame(width: 62, height: 62)
            .overlay { CutoutImage(fileName: cutout.fileName).padding(9) }
            .offset(x: x, y: y)
    }
}
