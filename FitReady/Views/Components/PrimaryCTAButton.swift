import SwiftUI

/// Full-width CTA button with press animation and light haptic.
struct PrimaryCTAButton: View {

    let label:  String
    let state:  ReadinessState
    let action: () -> Void

    @State private var isPressed = false

    private var buttonColor: Color {
        switch state {
        case .green:  return AppColors.greenText
        case .yellow: return AppColors.amberText
        case .red:    return AppColors.accent   // purple = calm / recovery
        }
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3)) { isPressed = false }
                Haptics.impact(.medium)
                action()
            }
        } label: {
            Text(label)
                .font(DS.Typography.body().weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(buttonColor)
                .clipShape(RoundedRectangle(cornerRadius: DS.Corner.button))
                .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
