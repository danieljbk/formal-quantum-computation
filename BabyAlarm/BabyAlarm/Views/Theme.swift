import SwiftUI

enum Theme {
    static let pink = Color(red: 0.98, green: 0.52, blue: 0.62)
    static let lilac = Color(red: 0.56, green: 0.45, blue: 0.88)
    static let night = Color(red: 0.16, green: 0.14, blue: 0.32)

    static var ringingGradient: LinearGradient {
        LinearGradient(colors: [pink, lilac], startPoint: .top, endPoint: .bottom)
    }

    static var headerGradient: LinearGradient {
        LinearGradient(colors: [lilac, night], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A wobbling, crying baby used on the ringing screen.
struct CryingBaby: View {
    let emoji: String
    @State private var wobble = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 210, height: 210)
                .scaleEffect(wobble ? 1.08 : 0.92)
            Text(emoji)
                .font(.system(size: 120))
                .rotationEffect(.degrees(wobble ? -9 : 9))
            Text("💧")
                .font(.system(size: 34))
                .offset(x: 62, y: wobble ? 40 : 10)
                .opacity(wobble ? 0.2 : 1)
        }
        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: wobble)
        .onAppear { wobble = true }
        .accessibilityLabel("A crying baby")
    }
}

/// Big rounded button used on full-screen alarm surfaces.
struct PillButton: View {
    let title: String
    var systemImage: String? = nil
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(filled ? Color.white : Color.white.opacity(0.18))
            .foregroundColor(filled ? Theme.night : .white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
