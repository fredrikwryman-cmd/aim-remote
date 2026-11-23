import SwiftUI

// R03 Inställningar. Mått enligt SPEC §R03, ljust läge samma layout med
// light-tokens. Ingen Enheter-rad (byggs inte).
@MainActor
struct SettingsScreen: View {
    @ObservedObject var connection: TVConnection
    @Binding var haptics: Bool
    @Binding var appearanceRaw: String
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme

    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ScrollView {
            VStack(spacing: 0) {
                Text("Inställningar")
                    .font(TR.Font.screenTitle)
                    .trLabelScaling()
                    .foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 23)

                hero.padding(.top, 18)

                VStack(spacing: 0) {
                    SettingsRow(icon: "tv", title: "TV och anslutning", value: connection.tvName) {
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
                                .tint(colors.green)
                        }
                    )
                    TRDivider()
                    SettingsRow(icon: "circle.lefthalf.filled", title: "Utseende", value: appearance.title) {
                        openPanel(.appearance)
                    }
                }
                .trCard()
                .padding(.top, 18)

                Text("v0.1.0 · Testversion")
                    .font(TR.Font.keyLabel)
                    .foregroundStyle(colors.muted)
                    .padding(.top, 18)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, TR.Size.sidePadding)
        }
    }

    // Hero-kort: 104 högt, radie 28, grön gradient 135 grader.
    private var hero: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.hero, style: .continuous)
        return Button {
            openPanel(.help)
        } label: {
            HStack(spacing: 14) {
                TRSymbol(width: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tech Rabbit Remote")
                        .font(TR.Font.heroTitle)
                        .trLabelScaling()
                        .foregroundStyle(colors.text)
                    Text("Din TV. Din kontroll.")
                        .font(TR.Font.keyLabel)
                        .trLabelScaling()
                        .foregroundStyle(colors.mutedOnHero)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colors.text)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x1ED63C, opacity: 0.42), Color(hex: 0x1ED63C, opacity: 0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: shape
            )
            .overlay(shape.stroke(Color(hex: 0x1CF038, opacity: 0.4), lineWidth: 1))
            .shadow(color: Color(hex: 0x1ED63C, opacity: 0.15), radius: 15, y: 10)
            .contentShape(shape)
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel("Tech Rabbit Remote, Din TV. Din kontroll.")
    }
}

// Utseende: Ljust, Mörkt, Automatiskt med bock vid valt läge.
@MainActor
struct AppearancePanel: View {
    @Binding var appearanceRaw: String
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let order: [AppearanceMode] = [.light, .dark, .system]

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Utseende", top: 220, onClose: onClose) {
            VStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, mode in
                    if index > 0 { TRDivider() }
                    Button {
                        if reduceMotion {
                            appearanceRaw = mode.rawValue
                        } else {
                            withAnimation(.easeInOut(duration: TR.Motion.themeSwap)) {
                                appearanceRaw = mode.rawValue
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.title)
                                .font(TR.Font.row)
                                .trLabelScaling()
                                .foregroundStyle(colors.text)
                            Spacer(minLength: 8)
                            if appearanceRaw == mode.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(colors.greenText)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: TR.Size.settingsRow)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TRPressStyle())
                    .accessibilityLabel(mode.title)
                    .accessibilityAddTraits(appearanceRaw == mode.rawValue ? .isSelected : [])
                }
            }
            .trCard()
            .padding(.top, 8)

            Text("Automatiskt följer telefonens inställning. Sol- och månknappen på fjärren växlar direkt mellan ljust och mörkt.")
                .font(TR.Font.caption)
                .foregroundStyle(colors.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 4)
        }
    }
}
