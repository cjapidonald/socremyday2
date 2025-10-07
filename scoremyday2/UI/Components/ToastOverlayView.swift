import SwiftUI

struct ToastOverlayView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let toast = appEnvironment.toast {
                    ToastBannerView(toast: toast, tint: accentColor)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appEnvironment.toast)
    }

    private var accentColor: Color {
        if let hex = appEnvironment.settings.accentColorHex, !hex.isEmpty {
            return Color(hex: hex, fallback: .accentColor)
        } else {
            return .accentColor
        }
    }
}

private struct ToastBannerView: View {
    let toast: AppEnvironment.Toast
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            if let icon = toast.iconSystemName {
                Image(systemName: icon)
                    .imageScale(.medium)
                    .font(.system(size: 16, weight: .semibold))
            }

            Text(toast.message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.leading)
                .foregroundStyle(foregroundStyle)
                .accessibilityLabel(toast.message)
                .padding(.vertical, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(background)
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 12)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1.2)
            )
    }

    private var foregroundStyle: some ShapeStyle {
        Color.primary
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        ToastOverlayView()
            .environmentObject({
                let environment = AppEnvironment()
                environment.showToast(message: "Demo data loaded.")
                return environment
            }())
    }
}
