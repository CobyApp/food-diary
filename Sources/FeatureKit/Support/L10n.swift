import Foundation

public enum L10n {
    /// Bundle and locale to read strings from, when they must not come from the
    /// system. Only the store-screenshot generator sets these: it renders every
    /// language in one process, which the system locale cannot express. nil in the
    /// app, where the system's own choice is the right one.
    nonisolated(unsafe) public static var overrideBundle: Bundle?
    nonisolated(unsafe) public static var overrideLocale: Locale?

    public static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: overrideBundle ?? .main, comment: "")
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: overrideLocale ?? .current, arguments: arguments)
    }
}
