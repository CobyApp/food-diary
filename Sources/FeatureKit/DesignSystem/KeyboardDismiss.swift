import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension View {
    /// A tap anywhere puts the keyboard away.
    ///
    /// Simultaneous on purpose: the tap is observed, not consumed, so buttons and
    /// drags underneath keep working. Sheets are separate presentations, so each
    /// one that holds a text field needs this too — it does not inherit from the
    /// screen behind it.
    func dismissesKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
                #endif
            }
        )
    }
}
