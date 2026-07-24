import Foundation

public enum ImageStoreError: Error { case writeFailed }

public struct ImageStore: Sendable {
    public var save: @Sendable (Data) throws -> String
    public var load: @Sendable (String) -> Data?
    public var delete: @Sendable (String) throws -> Void

    public init(
        save: @escaping @Sendable (Data) throws -> String,
        load: @escaping @Sendable (String) -> Data?,
        delete: @escaping @Sendable (String) throws -> Void
    ) {
        self.save = save
        self.load = load
        self.delete = delete
    }
}

public extension ImageStore {
    static func disk(directory: URL) -> ImageStore {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        return ImageStore(
            save: { data in
                let name = "\(UUID().uuidString).png"
                let url = directory.appendingPathComponent(name)
                do { try data.write(to: url) } catch { throw ImageStoreError.writeFailed }
                return name
            },
            load: { name in
                try? Data(contentsOf: directory.appendingPathComponent(name))
            },
            delete: { name in
                // Use FileManager.default directly rather than capturing `fm`,
                // which is not Sendable, in this @Sendable closure.
                let fm = FileManager.default
                let url = directory.appendingPathComponent(name)
                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
            }
        )
    }

    static var cutoutsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cutouts", isDirectory: true)
    }
}
