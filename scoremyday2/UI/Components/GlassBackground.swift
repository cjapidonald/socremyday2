import SwiftUI

struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var warpStrength: CGFloat

    @State private var targetLocation: CGPoint?
    @State private var animatedLocation: CGPoint?
    @State private var isInteracting = false

    func body(content: Content) -> some View {
        content
            .background(
                GlassMaterialView(
                    cornerRadius: cornerRadius,
                    tint: tint,
                    warpStrength: warpStrength,
                    interactionLocation: animatedLocation,
                    isInteracting: isInteracting
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .simultaneousGesture(dragGesture)
            .onChange(of: targetLocation) { newValue in
                withAnimation(.easeOut(duration: 0.28)) {
                    animatedLocation = newValue
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                targetLocation = value.location
                if !isInteracting {
                    isInteracting = true
                }
            }
            .onEnded { _ in
                targetLocation = nil
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    animatedLocation = nil
                }
                isInteracting = false
            }
    }
}

extension View {
    func glassBackground(
        cornerRadius: CGFloat = 20,
        tint: Color = .accentColor,
        warpStrength: CGFloat = 4
    ) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius, tint: tint, warpStrength: warpStrength))
    }
}

private struct GlassMaterialView: View {
    var cornerRadius: CGFloat
    var tint: Color
    var warpStrength: CGFloat
    var interactionLocation: CGPoint?
    var isInteracting: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityContrast) private var accessibilityContrastLevel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let normalized = normalizedPoint(in: size)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let offset = lensOffset(normalized: normalized)
            let scale = lensScale(normalized: normalized)

            Group {
                if reduceTransparency {
                    shape
                        .fill(Color(.systemBackground))
                        .overlay(
                            shape
                                .stroke(tint.opacity(colorScheme == .dark ? 0.45 : 0.3), lineWidth: accessibilityContrastLevel == .increased ? 1.6 : 1)
                        )
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .background(
                            shape
                                .fill(tintGradient(normalized: normalized))
                        )
                        .overlay(innerHighlight(shape: shape, normalized: normalized))
                        .overlay(glassBorder(shape: shape))
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
            .scaleEffect(reduceTransparency ? 1 : 1 + scale)
            .offset(reduceTransparency ? .zero : offset)
            .animation(reduceTransparency ? nil : .easeOut(duration: 0.35), value: normalized.x)
            .animation(reduceTransparency ? nil : .easeOut(duration: 0.35), value: normalized.y)
        }
    }

    private func normalizedPoint(in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        guard let location = interactionLocation else { return CGPoint(x: 0.5, y: 0.5) }
        let x = max(0, min(location.x / size.width, 1))
        let y = max(0, min(location.y / size.height, 1))
        return CGPoint(x: x, y: y)
    }

    private func tintGradient(normalized: CGPoint) -> LinearGradient {
        let baseOpacity = accessibilityContrastLevel == .increased ? 0.55 : 0.35
        let secondaryOpacity = accessibilityContrastLevel == .increased ? 0.42 : 0.25
        let tertiaryOpacity = accessibilityContrastLevel == .increased ? 0.25 : 0.15
        let adjustedTint = tint.opacity(colorScheme == .dark ? baseOpacity : baseOpacity * 0.8)
        let gradientColors: [Color] = [
            adjustedTint,
            tint.opacity(colorScheme == .dark ? secondaryOpacity : secondaryOpacity * 0.8),
            Color.white.opacity(colorScheme == .dark ? tertiaryOpacity : tertiaryOpacity * 1.6)
        ]
        let start = UnitPoint(x: normalized.x * 0.6, y: max(normalized.y - 0.3, 0))
        let end = UnitPoint(x: 1 - normalized.x * 0.4, y: 1)
        return LinearGradient(colors: gradientColors, startPoint: start, endPoint: end)
    }

    private func innerHighlight(shape: RoundedRectangle, normalized: CGPoint) -> some View {
        let highlightOpacity = accessibilityContrastLevel == .increased ? 0.75 : 0.55
        let highlightGradient = LinearGradient(
            colors: [
                Color.white.opacity(highlightOpacity),
                Color.white.opacity(0.1)
            ],
            startPoint: UnitPoint(x: normalized.x * 0.8, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
        let glow = shape
            .stroke(highlightGradient, lineWidth: accessibilityContrastLevel == .increased ? 1.8 : 1.1)
            .blendMode(.screen)
            .opacity(0.65)

        let innerShadow = shape
            .stroke(Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12), lineWidth: 1)
            .blur(radius: 1.2)
            .offset(x: 0, y: 1.2)
            .mask(shape)
            .opacity(0.5)

        return glow.overlay(innerShadow)
    }

    private func glassBorder(shape: RoundedRectangle) -> some View {
        let borderColor = tint.opacity(colorScheme == .dark ? 0.35 : 0.25)
        return shape
            .strokeBorder(borderColor, lineWidth: accessibilityContrastLevel == .increased ? 1.6 : 1)
            .blendMode(.plusLighter)
            .opacity(cornerRadius < 1 ? 0 : 0.8)
    }

    private var shadowColor: Color {
        guard cornerRadius > 0.5 else { return .clear }
        let baseOpacity: Double = colorScheme == .dark ? 0.55 : 0.25
        return Color.black.opacity(accessibilityContrastLevel == .increased ? baseOpacity * 0.6 : baseOpacity)
    }

    private var shadowRadius: CGFloat {
        guard cornerRadius > 0.5 else { return 0 }
        return accessibilityContrastLevel == .increased ? 10 : 18
    }

    private var shadowYOffset: CGFloat {
        guard cornerRadius > 0.5 else { return 0 }
        return accessibilityContrastLevel == .increased ? 6 : 12
    }

    private func lensOffset(normalized: CGPoint) -> CGSize {
        guard !reduceMotion else { return .zero }
        let clampedStrength = min(max(warpStrength, 0), 6)
        let multiplier: CGFloat = isInteracting ? 1 : 0.55
        let x = (normalized.x - 0.5) * clampedStrength * multiplier
        let y = (normalized.y - 0.5) * clampedStrength * multiplier
        return CGSize(width: x, height: y)
    }

    private func lensScale(normalized: CGPoint) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let distance = sqrt(pow(normalized.x - 0.5, 2) + pow(normalized.y - 0.5, 2))
        let maxScale: CGFloat = (accessibilityContrastLevel == .increased ? 0.008 : 0.012) * (isInteracting ? 1 : 0.6)
        return max(0, (1 - min(distance * 2, 1)) * maxScale)
    }
}
