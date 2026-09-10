import SwiftUI

// MARK: - Liquid Glass View Modifiers & Styles (Monochrome Glassmorphism)

public struct LiquidGlassWindowBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme

    public init(cornerRadius: CGFloat = 14) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 1. Native macOS blur material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // 2. Translucent deep glass tint
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.76)
                                : Color.white.opacity(0.80)
                        )

                    // 3. Top Specular Sheen (Liquid Glass surface reflection)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.65),
                                    colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .init(x: 0.5, y: 0.35)
                            )
                        )
                }
            )
            .overlay(
                // 4. Precision Beveled Specular Border (Prismatic Glass Rim)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.28) : Color.white.opacity(0.85),
                                colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                                colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

public struct LiquidGlassPopoverBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme

    public init(cornerRadius: CGFloat = 10) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            colorScheme == .dark
                                ? Color.black.opacity(0.85)
                                : Color.white.opacity(0.88)
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.75),
                                colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

public struct LiquidGlassHoverPill: ViewModifier {
    let isHovered: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme

    public init(isHovered: Bool, cornerRadius: CGFloat = 7) {
        self.isHovered = isHovered
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        isHovered
                            ? (colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.035))
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                isHovered
                                    ? (colorScheme == .dark
                                        ? LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.white.opacity(0.6), Color.black.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.5
                            )
                    )
            )
    }
}

public extension View {
    func liquidGlassWindow(cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlassWindowBackground(cornerRadius: cornerRadius))
    }

    func liquidGlassPopover(cornerRadius: CGFloat = 10) -> some View {
        modifier(LiquidGlassPopoverBackground(cornerRadius: cornerRadius))
    }

    func liquidGlassHover(isHovered: Bool, cornerRadius: CGFloat = 7) -> some View {
        modifier(LiquidGlassHoverPill(isHovered: isHovered, cornerRadius: cornerRadius))
    }
}
