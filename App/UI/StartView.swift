import SwiftUI

// R01 Start. Visas bara vid första start (tr.remote.onboarded) och alltid i mörkt läge.
@MainActor
struct StartView: View {
    var onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = TR.Colors.dark
        // Måtten i SPEC räknas från skärmens överkant, så lagret ligger utanför
        // safe area och innehållet placeras med fasta avstånd uppifrån.
        ZStack(alignment: .top) {
            RemoteBackground(variant: .start)
            VStack(spacing: 0) {
                TRSymbol(width: 96)
                Text("Tech Rabbit Remote")
                    .font(TR.Font.title)
                    .tracking(-0.5)
                    .foregroundStyle(colors.text)
                    .padding(.top, 34)
                Text("Din TV. Din kontroll.")
                    .font(TR.Font.body)
                    .foregroundStyle(Color(hex: 0xB8C4BB))
                    .padding(.top, 14)
            }
            .padding(.top, 220)
            .frame(maxWidth: .infinity)

            // Fortsätt-knappen: 64 x 64, överkant 580 från skärmens topp.
            continueButton
                .padding(.top, 580)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bgBottom)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }

    private var continueButton: some View {
        let shape = RoundedRectangle(cornerRadius: TR.Radius.splashButton, style: .continuous)
        return Button(action: onContinue) {
            Image(systemName: "chevron.right")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(TR.Colors.dark.text)
                .frame(width: TR.Size.splashButton, height: TR.Size.splashButton)
                .background(
                    LinearGradient(colors: [Color(hex: 0x1B4A26), Color(hex: 0x0F2A16)],
                                   startPoint: .top, endPoint: .bottom),
                    in: shape
                )
                .overlay(shape.stroke(Color(hex: 0x1CF038, opacity: 0.45), lineWidth: 1))
                .shadow(color: Color(hex: 0x1ED63C, opacity: 0.3), radius: 11)
                .contentShape(shape)
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel("Fortsätt till fjärrkontrollen")
    }
}
