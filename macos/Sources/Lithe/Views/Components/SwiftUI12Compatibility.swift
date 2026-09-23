import SwiftUI
@_exported import LitheModuleAPI

public extension View {
    @ViewBuilder
    func litheScrollBackgroundHidden() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

public struct LabeledContentCompat<Content: View>: View {
    let title: String
    let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.secondary)
            Spacer()
            content
        }
    }
}
