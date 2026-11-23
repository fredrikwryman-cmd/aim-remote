import SwiftUI

// Inställningar, ritad efter facit sid 3 (ljust) och sid 4 (mörkt).
// Ingen Utseende-rad: appen följer telefonens läge.
@MainActor
struct SettingsScreen: View {
    @ObservedObject var connection: TVConnection
    @Binding var haptics: Bool
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ScrollView {
            VStack(spacing: 0) {
                Text("Inställningar")
                    .font(TR.Font.largeTitle)
                    .trLabelScaling()
                    .foregroundStyle(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 15)

                hero.padding(.top, 21)

                VStack(spacing: 0) {
                    SettingsRow(icon: "tv", title: "TV och anslutning",
                                value: connection.ready ? connection.tvName : "Välj TV") {
                        openPanel(.connection)
                    }
                    TRDivider()
                    SettingsRow(icon: "questionmark.circle", title: "Hjälp") {
                        openPanel(.help)
                    }
                    TRDivider()
                    SettingsRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Knappvibration",
                        showsChevron: false,
                        accessory: {
                            Toggle("Knappvibration", isOn: $haptics)
                                .labelsHidden()
                                .tint(colors.accent)
                        }
                    )
                }
                .trCard()
                .padding(.top, 22)

                Text("v0.1.0 · Testversion")
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .foregroundStyle(colors.textSecondary)
                    .padding(.top, 23)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, TR.Size.sidePadding)
        }
    }

    // Kortet: grön appikon, namn och undertext. Ingen chevron i facit.
    private var hero: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.hero, style: .continuous)
        let tile = RoundedRectangle(cornerRadius: TR.Radius.heroIcon, style: .continuous)
        return Button {
            openPanel(.help)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "appletvremote.gen4.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(colors.accent)
                    .frame(width: TR.Size.heroIcon, height: TR.Size.heroIcon)
                    .background(tile.fill(colors.accent.opacity(scheme == .dark ? 0.16 : 0.20)))
                    .overlay(tile.stroke(colors.accent.opacity(0.30), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tech Rabbit Remote")
                        .font(TR.Font.cardTitle)
                        .trLabelScaling()
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Din TV. Din kontroll.")
                        .font(TR.Font.body)
                        .trLabelScaling()
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, TR.Size.heroPadding)
            .frame(maxWidth: .infinity)
            .frame(height: TR.Size.heroCard)
            .background(shape.fill(colors.panel))
            .overlay(shape.stroke(colors.line, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel("Tech Rabbit Remote, Din TV. Din kontroll.")
    }
}
