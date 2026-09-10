import SwiftUI

/// Clean, high-contrast animated strikethrough line
public struct InkStrikethroughLine: View {
    let isCompleted: Bool
    @Environment(\.colorScheme) var colorScheme

    public init(isCompleted: Bool) {
        self.isCompleted = isCompleted
    }

    public var body: some View {
        GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .trim(from: 0, to: isCompleted ? 1 : 0)
            .stroke(
                colorScheme == .dark ? Color(white: 0.4) : Color(white: 0.6),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .square)
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isCompleted)
        }
    }
}

/// Subtle snappy pulse ring on completion (Apple minimal)
public struct DotPulseRing: View {
    let progress: Double
    let color: Color

    public init(progress: Double, color: Color) {
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        Circle()
            .stroke(color.opacity((1.0 - progress) * 0.9), lineWidth: 1.5)
            .scaleEffect(1.0 + CGFloat(progress) * 1.8)
            .opacity(progress > 0 && progress < 1 ? 1 : 0)
    }
}
