import Dependencies
import DependenciesMacros
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writes a selected recap period's closing line with Apple Intelligence, on device.
///
/// Returns `nil` whenever generation isn't possible — the device doesn't support
/// Apple Intelligence, the user hasn't enabled it, the model is still
/// downloading, or the request failed — so callers fall back to a localized
/// static line instead of showing nothing.
@DependencyClient
public struct CaptionClient: Sendable {
    /// - Parameters:
    ///   - mealCount: how many meals the selected period holds.
    ///   - places: restaurant names from that period (may be empty).
    ///   - languageCode: BCP-47 code of the UI language, so the caption comes
    ///     back in the language the user is actually reading.
    public var weeklyCaption: @Sendable (
        _ mealCount: Int,
        _ places: [String],
        _ languageCode: String
    ) async -> String?
}

extension CaptionClient: DependencyKey {
    public static let liveValue = CaptionClient(
        weeklyCaption: { mealCount, places, languageCode in
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, *) else { return nil }
            guard SystemLanguageModel.default.isAvailable else { return nil }

            let language = Self.languageName(for: languageCode)
            let session = LanguageModelSession(
                instructions: """
                You write one short closing line for a food diary recap card.
                Rules: reply with the line only — no quotes, no emoji, no hashtags, \
                no explanation. Keep it under 24 characters. Warm, playful, first \
                person, past tense. Write it in \(language).
                """
            )

            let placeList = places.isEmpty
                ? "no restaurant names recorded"
                : places.prefix(6).joined(separator: ", ")
            let prompt = """
            During this recap period I ate \(mealCount) meal(s). Places: \(placeList).
            Write the closing line.
            """

            do {
                let response = try await session.respond(to: prompt)
                return Self.tidy(response.content)
            } catch {
                return nil
            }
            #else
            return nil
            #endif
        }
    )

    /// Trim the model's answer down to something that fits the card.
    static func tidy(_ raw: String) -> String? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep only the first line if the model got chatty.
        if let firstLine = line.split(separator: "\n").first {
            line = String(firstLine).trimmingCharacters(in: .whitespaces)
        }
        // Strip wrapping quotes the model sometimes adds.
        let quotes: Set<Character> = ["\"", "'", "“", "”", "‘", "’", "「", "」"]
        while let first = line.first, quotes.contains(first) { line.removeFirst() }
        while let last = line.last, quotes.contains(last) { line.removeLast() }
        line = line.trimmingCharacters(in: .whitespaces)

        guard !line.isEmpty, line.count <= 40 else { return nil }
        return line
    }

    /// English language names keep the instruction unambiguous for the model.
    static func languageName(for code: String) -> String {
        switch code.split(separator: "-").first.map(String.init) ?? code {
        case "ko": return "Korean"
        case "ja": return "Japanese"
        case "zh": return "Simplified Chinese"
        default: return "English"
        }
    }
}

extension CaptionClient: TestDependencyKey {
    public static let testValue = CaptionClient()
    public static let previewValue = CaptionClient(
        weeklyCaption: { _, _, _ in "오늘도 맛있게 먹었어요" }
    )
}

public extension DependencyValues {
    var caption: CaptionClient {
        get { self[CaptionClient.self] }
        set { self[CaptionClient.self] = newValue }
    }
}
