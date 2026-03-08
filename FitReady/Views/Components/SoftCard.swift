import SwiftUI

/// Elevated card surface — dark raised bg with border, no shadow.
struct SoftCard<Content: View>: View {

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: DS.Corner.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Corner.card)
                .strokeBorder(DS.Border.color, lineWidth: 1)
        )
    }
}
