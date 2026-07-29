import Foundation

/// The local device's player identity in a Game Center match.
public struct LocalPlayer: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
}

/// A player identity as observed for a remote participant in a Game Center match.
public struct RemotePlayer: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
}

/// A single player's menu selection, shared with other players in the match.
public struct MenuPick: Equatable, Sendable, Codable, Identifiable {
    public var id: String { playerID }
    public let playerID: String
    public let playerName: String
    public let thumbnail: Data
    public let tags: [String]
    public let placeName: String
    public let address: String
    public init(playerID: String, playerName: String, thumbnail: Data,
                tags: [String], placeName: String, address: String) {
        self.playerID = playerID; self.playerName = playerName; self.thumbnail = thumbnail
        self.tags = tags; self.placeName = placeName; self.address = address
    }
}

/// Wire protocol exchanged between players over the Game Center match connection.
public enum MultiplayerMessage: Equatable, Sendable, Codable {
    case menu(MenuPick)
    case bracket([String])                    // candidate order (playerIDs), from the host
    case pair(index: Int)                     // which match is live
    case vote(candidateID: String)            // a player's vote for the live match
    case roundResult(winnerID: String, leftVotes: Int, rightVotes: Int)
    case champion(String)
}

/// Local events surfaced from the multiplayer session to the app layer.
public enum MultiplayerEvent: Equatable, Sendable {
    case playersChanged([RemotePlayer])
    case received(MultiplayerMessage, from: String)
    case matchEnded
}
