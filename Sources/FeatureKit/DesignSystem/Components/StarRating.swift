import SwiftUI

public struct StarRating: View {
    private let rating: Int?
    private let onChange: ((Int?) -> Void)?

    /// `onChange == nil` renders a compact read-only row; otherwise an editable
    /// row where tapping a star sets 1...5, and re-tapping the current value clears to nil.
    public init(rating: Int?, onChange: ((Int?) -> Void)? = nil) {
        self.rating = rating
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                let filled = i <= (rating ?? 0)
                Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: onChange == nil ? 15 : 24))
                    .foregroundStyle(filled ? Color.appButterInk : Color.appMuted.opacity(0.5))
                    .onTapGesture {
                        guard let onChange else { return }
                        onChange(rating == i ? nil : i)
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StarRating(rating: 4)
        StarRating(rating: 3, onChange: { _ in })
    }
    .padding().background(Color.appMilk)
}
