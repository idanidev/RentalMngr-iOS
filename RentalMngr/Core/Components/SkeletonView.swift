import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Color.secondary.opacity(0.1)

                // Shimmer
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.5),
                        .clear,
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Modifier for easy usage
extension View {
    func skeleton(active: Bool = true) -> some View {
        self.redacted(reason: active ? .placeholder : [])
            .shimmering(active: active)
    }
}

// Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    var active: Bool

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear,
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: phase * geometry.size.width)
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

#Preview {
    VStack {
        Text("Hello World")
            .font(.title)
            .skeleton(active: true)
            .frame(width: 200, height: 30)

        SkeletonView()
            .frame(height: 200)
            .padding()
    }
}
