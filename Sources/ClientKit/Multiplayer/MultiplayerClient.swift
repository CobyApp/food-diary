import Dependencies
import DependenciesMacros

public enum MultiplayerError: Error, Equatable { case notAuthenticated, matchmakingCancelled, noMatch }

@DependencyClient
public struct MultiplayerClient: Sendable {
    public var authenticate: @Sendable () async throws -> LocalPlayer
    public var startMatch: @Sendable () async throws -> Void
    public var events: @Sendable () -> AsyncStream<MultiplayerEvent> = { .finished }
    public var send: @Sendable (_ message: MultiplayerMessage) async throws -> Void
    public var disconnect: @Sendable () -> Void
}

extension MultiplayerClient: TestDependencyKey {
    public static let testValue = MultiplayerClient()
    public static let previewValue = MultiplayerClient(
        authenticate: { LocalPlayer(id: "me", displayName: "나") },
        startMatch: {},
        events: { .finished },
        send: { _ in },
        disconnect: {}
    )
}

public extension DependencyValues {
    var multiplayer: MultiplayerClient {
        get { self[MultiplayerClient.self] }
        set { self[MultiplayerClient.self] = newValue }
    }
}
