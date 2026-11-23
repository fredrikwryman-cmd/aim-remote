import SwiftUI

// Bladet enligt SPEC R04: material och scrim över fjärren, radie 34,
// gradient sheetTop → sheetBottom. In 280 ms, ut 200 ms. Stängs med X,
// tryck på scrimmen eller nedsvep.
@MainActor
struct GlassSheet<Content: View>: View {
    var title: String
    var top: CGFloat = 150
    var onClose: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ZStack(alignment: .top) {
            // Fjärren suddas och dimmas bakom bladet.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            colors.scrim
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                header
                content
            }
            .padding(.top, 18)
            .padding(.horizontal, 14)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [colors.sheetTop, colors.sheetBottom],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: TR.Radius.sheet, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TR.Radius.sheet, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .padding(.horizontal, 14)
            .padding(.top, top)
            .offset(y: max(0, drag))
            .gesture(
                DragGesture()
                    .onChanged { value in drag = value.translation.height }
                    .onEnded { value in
                        if value.translation.height > 80 {
                            onClose()
                        } else {
                            withAnimation(.easeOut(duration: TR.Motion.sheetOut)) { drag = 0 }
                        }
                    }
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    private var header: some View {
        let colors = TR.Colors.of(scheme)
        return ZStack {
            Text(title)
                .font(TR.Font.sheetTitle)
                .trLabelScaling()
                .foregroundStyle(colors.text)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colors.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TRPressStyle())
                .accessibilityLabel("Stäng")
            }
        }
        .frame(height: 44)
    }
}

// Rad i inställningskortet och i panelerna: 52 hög, ikon 20, etikett 15 w500.
@MainActor
struct SettingsRow: View {
    var icon: String
    var title: String
    var value: String = ""
    var showsChevron = true
    var accessory: AnyView?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    /// Rad utan tillbehör. En efterställd stängning är alltid handlingen.
    init(icon: String, title: String, value: String = "",
         showsChevron: Bool = true, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showsChevron = showsChevron
        self.accessory = nil
        self.action = action
    }

    /// Rad med tillbehör (vippa, snurra). Tillbehöret skickas alltid med
    /// etiketten `accessory:`. Då kan en efterställd stängning bara träffa
    /// `action`, och initieraren blir aldrig tvetydig.
    init<Accessory: View>(icon: String, title: String, value: String = "",
                          showsChevron: Bool = true,
                          @ViewBuilder accessory: () -> Accessory,
                          action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showsChevron = showsChevron
        self.accessory = AnyView(accessory())
        self.action = action
    }

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let row = HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(colors.text)
                .frame(width: 24)
            Text(title)
                .font(TR.Font.row)
                .trLabelScaling()
                .foregroundStyle(colors.text)
            Spacer(minLength: 8)
            if !value.isEmpty {
                Text(value)
                    .font(TR.Font.rowValue)
                    .trLabelScaling()
                    .foregroundStyle(colors.muted)
                    .lineLimit(1)
            }
            if let accessory { accessory }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.muted)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: TR.Size.settingsRow)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(TRPressStyle())
                .accessibilityLabel(value.isEmpty ? title : "\(title), \(value)")
        } else {
            row
        }
    }
}

// Primärknapp: höjd 52, radie 26, gradient #2FD44A → #13A82E, glöd.
@MainActor
struct TRPrimaryButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TR.Radius.primaryButton, style: .continuous)
        Button(action: action) {
            Text(title)
                .font(.custom("Archivo-Bold", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: TR.Size.primaryButton)
                .background(
                    LinearGradient(colors: [TR.PrimaryButton.top, TR.PrimaryButton.bottom],
                                   startPoint: .top, endPoint: .bottom),
                    in: shape
                )
                .overlay(shape.stroke(TR.PrimaryButton.border, lineWidth: 1))
                .shadow(color: Color(hex: 0x1ED63C, opacity: 0.35), radius: 10)
                .contentShape(shape)
        }
        .buttonStyle(TRPressStyle())
        .opacity(isEnabled ? 1 : 0.4)
    }
}

// Kort med panelbakgrund och kant, används i R03 och i panelerna.
struct TRCard: ViewModifier {
    var radius: CGFloat = TR.Radius.card
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(colors.panel, in: shape)
            .overlay(shape.stroke(colors.line, lineWidth: 1))
    }
}

extension View {
    func trCard(radius: CGFloat = TR.Radius.card) -> some View { modifier(TRCard(radius: radius)) }
}

struct TRDivider: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(TR.Colors.of(scheme).divider)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// Felmeddelande inne i den öppna panelen.
@MainActor
struct PanelNotice: View {
    @ObservedObject var connection: TVConnection
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        if let notice = connection.notice {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 17))
                    .foregroundStyle(colors.power)
                Text(notice)
                    .font(TR.Font.rowValue)
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button { connection.notice = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dölj meddelandet")
            }
            .padding(.leading, 14)
            .background(colors.power.opacity(0.12), in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}
