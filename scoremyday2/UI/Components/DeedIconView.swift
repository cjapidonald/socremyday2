import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DeedIconView: View {
    let value: String
    var fontSize: CGFloat = 30

    var body: some View {
        Group {
            if let symbolName = symbolNameIfValid(value) {
                Image(systemName: symbolName)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Text(value)
            }
        }
        .font(.system(size: fontSize))
    }

    private func symbolNameIfValid(_ input: String) -> String? {
        #if canImport(UIKit)
        if UIImage(systemName: input) != nil {
            return input
        }
        #elseif canImport(AppKit)
        if NSImage(systemSymbolName: input, accessibilityDescription: nil) != nil {
            return input
        }
        #endif
        return nil
    }
}

#Preview {
    VStack(spacing: 16) {
        DeedIconView(value: "🪥")
        DeedIconView(value: "square.and.pencil")
    }
}
