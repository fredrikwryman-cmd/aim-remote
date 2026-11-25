import SwiftUI

// Inställningar, ritad efter facit sid 3 (ljust) och sid 4 (mörkt).
// Utseende-raden ritas i samma stil som de övriga raderna på sidorna.
@MainActor
struct SettingsScreen: View {
    @ObservedObject var connection: TVConnection
    @Binding var haptics: Bool
    @Binding var appearanceRaw: String
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Punkt 16: rubriken krymper in i toppfältet när sidan scrollas.
    @State private var scrolled: CGFloat = 0

    private let space = "trSettingsScroll"

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SettingsScrollKey.self,
                        value: -proxy.frame(in: .named(space)).minY
                    )
                }
                .frame(height: 0)

                Text("Inställningar")
                    .font(TR.Font.largeTitle)
                    .trLabelScaling()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 15)
                    .opacity(Double(1 - collapse))
                    .scaleEffect(reduceMotion ? 1 : 1 - collapse * 0.14, anchor: .top)

                hero.padding(.top, 21)

                VStack(spacing: 0) {
                    SettingsRow(icon: "tv", title: "TV och anslutning",
                                value: connection.ready ? connection.tvName : "Välj TV",
                                customIcon: AnyView(
                                    TRDisplayIcon(width: 26, color: colors.textPrimary)
                                )) {
                        openPanel(.connection)
                    }
                    .panelSource(.connection)
                    TRDivider()
                    SettingsRow(icon: "circle.lefthalf.filled", title: "Utseende",
                                value: appearance.title) {
                        openPanel(.appearance)
                    }
                    .panelSource(.appearance)
                    TRDivider()
                    SettingsRow(icon: "questionmark.circle", title: "Hjälp") {
                        openPanel(.help)
                    }
                    .panelSource(.help)
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

                Text(AppVersion.label)
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .foregroundStyle(colors.textSecondary)
                    .padding(.top, 23)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, TR.Size.sidePadding)
        }
        .coordinateSpace(name: space)
        .onPreferenceChange(SettingsScrollKey.self) { scrolled = $0 }
        .overlay(alignment: .top) { topBar }
    }

    /// 0 vid toppen, 1 när rubriken sitter i toppfältet.
    private var collapse: CGFloat {
        min(max(scrolled / 48, 0), 1)
    }

    /// Toppfältet ligger som ett lager över sidan, så layouten i vila är
    /// oförändrad. Avdelaren syns först när innehåll ligger under fältet.
    private var topBar: some View {
        let colors = TR.Colors.of(scheme)
        return VStack(spacing: 0) {
            ZStack {
                colors.background.opacity(0.96)
                Text("Inställningar")
                    .font(TR.Font.deviceTitle)
                    .trLabelScaling()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(colors.textPrimary)
            }
            .frame(height: 44)
            Rectangle()
                .fill(colors.divider)
                .frame(height: 1)
                .opacity(scrolled > 4 ? 1 : 0)
        }
        .opacity(Double(collapse))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .standard
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

// Utseende: Mörkt, Ljust och Följ telefonen, med bock vid valt läge. Raderna
// har samma höjd och samma typografi som raderna i Inställningar.
@MainActor
struct AppearancePanel: View {
    @Binding var appearanceRaw: String
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let order: [AppearanceMode] = [.dark, .light, .system]

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Utseende", top: 220, onClose: onClose) {
            VStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, mode in
                    if index > 0 { TRDivider() }
                    Button {
                        TRHaptics.selection()
                        if reduceMotion {
                            appearanceRaw = mode.rawValue
                        } else {
                            withAnimation(.easeInOut(duration: TRMotion.theme)) {
                                appearanceRaw = mode.rawValue
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.title)
                                .font(TR.Font.body)
                                .trLabelScaling()
                                .foregroundStyle(colors.textPrimary)
                            Spacer(minLength: 8)
                            if appearanceRaw == mode.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(colors.accentText)
                            }
                        }
                        .padding(.horizontal, TR.Size.rowPadding)
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

            Text("Följ telefonen betyder att appen byter när iPhone byter mellan ljust och mörkt läge.")
                .font(TR.Font.caption)
                .foregroundStyle(colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .padding(.horizontal, 4)
        }
    }
}


/// Hur långt Inställningar har scrollats.
struct SettingsScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
