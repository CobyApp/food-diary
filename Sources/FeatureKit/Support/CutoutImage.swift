import SwiftUI
import ClientKit

public struct CutoutImage: View {
    private let fileName: String?
    private let immediateData: Data?
    @State private var loaded: Data?

    public init(fileName: String) { self.fileName = fileName; self.immediateData = nil }
    public init(data: Data) { self.fileName = nil; self.immediateData = data }

    public var body: some View {
        let data = immediateData ?? loaded
        Group {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(.quaternary)
            }
        }
        .task(id: fileName) {
            guard immediateData == nil, let fileName else { return }
            let name = fileName
            loaded = await Task.detached { ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(name) }.value
        }
    }
}
