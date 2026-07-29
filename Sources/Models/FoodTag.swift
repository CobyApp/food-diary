import Foundation
import SwiftData

/// A tag the user made up themselves, kept in a catalog so it can be reused,
/// renamed, and deleted across meals.
///
/// Meals store tag *names*, not references. Renaming therefore rewrites the name
/// on every meal that carries it — one repository call — which keeps every view
/// that displays a tag free of lookups.
@Model
public final class FoodTag {
    @Attribute(.unique) public var name: String
    public var createdAt: Date

    public init(name: String, createdAt: Date = Date()) {
        self.name = name
        self.createdAt = createdAt
    }
}

/// Rules for turning what someone typed into a tag, and for telling two tags
/// apart. Pure so the behaviour is pinned by tests rather than by the text field.
public enum TagName {
    /// Longer than this and a tag stops fitting on a sticker.
    public static let maxLength = 16

    /// Returns nil when there is no tag in the input at all.
    public static func normalize(_ raw: String) -> String? {
        // A leading hash is how people write tags; it isn't part of the name.
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix("#") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Collapse inner runs of whitespace so "매운 　 라멘" is one tag.
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    /// Two tags are the same tag when they differ only in case.
    public static func isSame(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Normalises, drops blanks, and removes repeats while keeping the order the
    /// user picked them in.
    public static func cleaned(_ raw: [String]) -> [String] {
        var result: [String] = []
        for name in raw.compactMap(normalize) where !result.contains(where: { isSame($0, name) }) {
            result.append(name)
        }
        return result
    }

    /// A stable palette slot for a tag, so the same tag is always the same colour
    /// without storing one.
    public static func tintIndex(for name: String, paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        // Sum of scalars rather than hashValue: hashing is seeded per process, so
        // a tag would change colour every launch.
        let total = name.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return total % paletteCount
    }
}
