import GameKit
import UIKit
import Dependencies

// Live GameKit adapter. NOTE: real behavior is verifiable only on device with
// Game Center accounts — this compiles and follows GameKit conventions but is
// expected to need on-device iteration.
final class GameCenterCoordinator: NSObject, GKMatchDelegate, GKMatchmakerViewControllerDelegate, @unchecked Sendable {
    static let shared = GameCenterCoordinator()

    private var match: GKMatch?
    private let (stream, continuation) = AsyncStream<MultiplayerEvent>.makeStream()
    private var matchmakeContinuation: CheckedContinuation<Void, Error>?

    func eventStream() -> AsyncStream<MultiplayerEvent> { stream }

    func authenticate() async throws -> LocalPlayer {
        if GKLocalPlayer.local.isAuthenticated {
            return LocalPlayer(id: GKLocalPlayer.local.gamePlayerID, displayName: GKLocalPlayer.local.displayName)
        }
        return try await withCheckedThrowingContinuation { cont in
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                if let viewController {
                    Task { @MainActor in self?.topViewController()?.present(viewController, animated: true) }
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    cont.resume(returning: LocalPlayer(id: GKLocalPlayer.local.gamePlayerID,
                                                       displayName: GKLocalPlayer.local.displayName))
                } else {
                    cont.resume(throwing: error ?? MultiplayerError.notAuthenticated)
                }
                GKLocalPlayer.local.authenticateHandler = nil
            }
        }
    }

    @MainActor
    func startMatch() async throws {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4
        guard let vc = GKMatchmakerViewController(matchRequest: request) else { throw MultiplayerError.noMatch }
        vc.matchmakerDelegate = self
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.matchmakeContinuation = cont
            topViewController()?.present(vc, animated: true)
        }
    }

    func send(_ message: MultiplayerMessage) throws {
        guard let match else { throw MultiplayerError.noMatch }
        let data = try JSONEncoder().encode(message)
        // `sendData(toAllPlayers:with:)` takes the Data as its first argument, not the
        // player list — the current GameKit API for sending to an explicit player set
        // is `send(_:to:dataMode:)`, which is what actually transmits the encoded payload.
        try match.send(data, to: match.players, dataMode: .reliable)
    }

    func disconnect() { match?.disconnect(); match = nil }

    // MARK: GKMatchmakerViewControllerDelegate
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
        matchmakeContinuation?.resume(throwing: MultiplayerError.matchmakingCancelled)
        matchmakeContinuation = nil
    }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        matchmakeContinuation?.resume(throwing: error)
        matchmakeContinuation = nil
    }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        match.delegate = self
        self.match = match
        emitPlayers()
        matchmakeContinuation?.resume(returning: ())
        matchmakeContinuation = nil
    }

    // MARK: GKMatchDelegate
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        if let msg = try? JSONDecoder().decode(MultiplayerMessage.self, from: data) {
            continuation.yield(.received(msg, from: player.gamePlayerID))
        }
    }
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        emitPlayers()
        if match.expectedPlayerCount == 0 { /* all connected */ }
    }

    private func emitPlayers() {
        let players = (match?.players ?? []).map { RemotePlayer(id: $0.gamePlayerID, displayName: $0.displayName) }
        continuation.yield(.playersChanged(players))
    }

    @MainActor private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension MultiplayerClient: DependencyKey {
    public static let liveValue: MultiplayerClient = {
        let coordinator = GameCenterCoordinator.shared
        return MultiplayerClient(
            authenticate: { try await coordinator.authenticate() },
            startMatch: { try await coordinator.startMatch() },
            events: { coordinator.eventStream() },
            send: { message in try coordinator.send(message) },
            disconnect: { coordinator.disconnect() }
        )
    }()
}
