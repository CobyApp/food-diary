import SwiftUI
import ClientKit

public struct CutoutImage: View {
    let data: Data?
    public init(fileName: String) {
        self.data = ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(fileName)
    }
    public init(data: Data) { self.data = data }

    public var body: some View {
        if let data, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 12).fill(.quaternary)
        }
    }
}
