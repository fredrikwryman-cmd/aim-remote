import SwiftUI

enum Theme {
    static let background = Color(red: 0.015, green: 0.055, blue: 0.075)
    static let green = Color(red: 0.19, green: 0.78, blue: 0.35)
    static let muted = Color(red: 0.55, green: 0.57, blue: 0.64)
    static let top = Color(red: 0.085, green: 0.10, blue: 0.13)
    static let bottom = Color(red: 0.18, green: 0.20, blue: 0.23)
}

struct RemoteButtonStyle: ButtonStyle {
    var rounded: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [Theme.top, Theme.bottom], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: rounded, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: rounded, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
