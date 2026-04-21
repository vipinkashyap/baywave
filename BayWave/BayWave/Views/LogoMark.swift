import SwiftUI

/// Minimal mark: amber disc, serif "B" in navy, small signal dot at top-right.
struct LogoMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(Theme.amber)

            Text("B")
                .font(.system(size: size * 0.6, weight: .bold, design: .serif))
                .foregroundStyle(Theme.navyDeep)

            Circle()
                .fill(Theme.navyDeep)
                .frame(width: size * 0.20, height: size * 0.20)
                .overlay(
                    Circle()
                        .fill(Theme.amber)
                        .padding(size * 0.04)
                )
                .offset(x: size * 0.34, y: -size * 0.34)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Theme.navyDeep.ignoresSafeArea()
        HStack(spacing: 24) {
            LogoMark(size: 22)
            LogoMark(size: 64)
            LogoMark(size: 128)
        }
    }
}
