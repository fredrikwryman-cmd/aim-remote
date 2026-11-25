import SwiftUI
import UIKit
import AiMCore

// MARK: - R04 Välj TV

@MainActor
struct ChooseTVPanel: View {
    @ObservedObject var connection: TVConnection
    var onClose: () -> Void

    @StateObject private var discovery = TVDiscovery()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNewHost = ""
    @State private var code = ""
    @State private var forgetTarget: SavedTV?
    /// Punkt 12: tomt läge efter ungefär 8 sekunder utan träff.
    @State private var emptyShown = false
    @State private var searchToken = 0
    /// Punkt 13: fel kod skakar fältet, rätt kod firas.
    @State private var codeSubmitted = false
    @State private var shake: CGFloat = 0

    // Bara det som TVDiscovery hittar via _androidtvremote2, minus det som
    // redan är sparat.
    private var discovered: [DiscoveredTV] {
        let known = Set(connection.savedTVs.map { $0.host.lowercased() })
        return discovery.devices.filter { !known.contains($0.host.lowercased()) }
    }

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Välj TV", top: 150, onClose: onClose) {
            VStack(spacing: 0) {
                PanelNotice(connection: connection)
                    .padding(.top, 8)

                if connection.savedTVs.isEmpty && discovered.isEmpty {
                    if emptyShown {
                        Text("Ingen TV hittades. Kontrollera att TV:n är på och på samma wifi.")
                            .font(TR.Font.body)
                            .foregroundStyle(colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 28)
                        TRPrimaryButton(title: "Sök igen") { searchAgain() }
                            .padding(.horizontal, 14)
                    } else {
                        // Laddningsskelett i rätt form, ingen ensam snurra.
                        VStack(spacing: 8) {
                            TRSkeletonRow()
                            TRSkeletonRow()
                            TRSkeletonRow()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Söker efter TV-apparater")
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(connection.savedTVs.enumerated()), id: \.element.id) { index, tv in
                                if index > 0 { TRDivider() }
                                SwipeToForget(onForget: {
                                    withAnimation(TRMotion.crossfade) { forgetTarget = tv }
                                }) {
                                    row(
                                        name: tv.name,
                                        detail: tv.host,
                                        selected: connection.activeTVID == tv.id,
                                        saved: true
                                    ) {
                                        TRHaptics.selection()
                                        selectedNewHost = ""
                                        connection.select(tv)
                                    }
                                }
                            }
                            if !discovered.isEmpty {
                                Text("NYA PÅ NÄTVERKET")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(0.3)
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 14)
                                    .padding(.bottom, 4)
                                ForEach(Array(discovered.enumerated()), id: \.element.id) { index, device in
                                    if index > 0 { TRDivider() }
                                    row(
                                        name: device.name,
                                        detail: device.host,
                                        selected: selectedNewHost == device.host,
                                        saved: false
                                    ) {
                                        TRHaptics.selection()
                                        selectedNewHost = device.host
                                    }
                                    .transition(
                                        reduceMotion
                                            ? .opacity
                                            : .opacity.combined(with: .offset(y: 10))
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .padding(.top, 6)
                    // Nya TV:ar glider in i stället för att hoppa (punkt 11).
                    .animation(TRMotion.spring(reduceMotion, TRMotion.smooth),
                               value: discovered.count)

                    if connection.needsCode {
                        codeField.padding(.top, 10)
                    }

                    if connection.needsRepair {
                        Text("TV:n visade ett annat certifikat än den sparade. Parkoppla igen om det är din TV.")
                            .font(TR.Font.caption)
                            .foregroundStyle(colors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                    }

                    TRPrimaryButton(title: primaryTitle) { primaryAction() }
                        .disabled(primaryDisabled)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                }
            }
        }
        .onAppear {
            discovery.start()
            armEmptyState()
        }
        .onDisappear { discovery.stop() }
        .onChange(of: connection.ready) { ready in
            guard ready else { return }
            codeSubmitted = false
            // Punkt 13: TV:n landar i listan som Ansluten, sedan stängs
            // panelen. Haptiken success kommer från RemoteRoot.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                onClose()
            }
        }
        .onChange(of: connection.notice) { notice in
            guard notice != nil, codeSubmitted else { return }
            codeSubmitted = false
            TRHaptics.error()
            shakeCode()
        }
        // Punkt 14: bekräftelseark med konsekvensen i klartext.
        .overlay {
            if let tv = forgetTarget {
                TRConfirmSheet(
                    title: "Glöm \(tv.name)?",
                    message: forgetMessage(host: tv.host),
                    confirmTitle: "Glöm \(tv.name)",
                    onConfirm: {
                        connection.forget(id: tv.id)
                        withAnimation(TRMotion.crossfade) { forgetTarget = nil }
                    },
                    onCancel: {
                        withAnimation(TRMotion.crossfade) { forgetTarget = nil }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    /// Punkt 12: tomt läge visas först när sökningen hunnit en stund.
    private func armEmptyState() {
        searchToken += 1
        let token = searchToken
        emptyShown = false
        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(TRMotion.emptyStateDelay * 1_000_000_000))
            guard token == searchToken, discovery.devices.isEmpty else { return }
            withAnimation(TRMotion.crossfade) { emptyShown = true }
        }
    }

    private func searchAgain() {
        discovery.stop()
        discovery.start()
        armEmptyState()
    }

    private func shakeCode() {
        guard !reduceMotion else { return }
        let steps: [CGFloat] = [-8, 7, -5, 3, 0]
        for (index, offset) in steps.enumerated() {
            withAnimation(.linear(duration: 0.05).delay(Double(index) * 0.05)) {
                shake = offset
            }
        }
    }

    private func forgetMessage(host: String) -> String {
        let consequence = "Du måste skriva in koden från TV:n igen för att ansluta."
        return host.isEmpty ? consequence : "\(consequence) (\(host))"
    }

    private var primaryTitle: String {
        if connection.needsCode { return "Bekräfta kod" }
        if connection.busy { return "Ansluter…" }
        if connection.needsRepair { return "Parkoppla igen" }
        return selectedNewHost.isEmpty ? "Anslut" : "Parkoppla"
    }

    private var primaryDisabled: Bool {
        if connection.needsCode { return code.count != 6 }
        if connection.busy { return true }
        if !selectedNewHost.isEmpty { return false }
        return connection.activeTVID == nil && !connection.needsRepair
    }

    private func primaryAction() {
        if connection.needsCode {
            codeSubmitted = true
            connection.submit(code: code)
            return
        }
        if let device = discovered.first(where: { $0.host == selectedNewHost }) {
            // Ny TV: parkoppla och spara när koden stämmer.
            connection.disconnect()
            connection.host = device.host
            connection.tvName = device.name
            connection.connect(pair: true)
            return
        }
        if connection.needsRepair {
            connection.connect(pair: true)
            return
        }
        if let active = connection.savedTVs.first(where: { $0.id == connection.activeTVID }) {
            connection.select(active)
        }
    }

    private func row(name: String, detail: String, selected: Bool, saved: Bool,
                     action: @escaping () -> Void) -> some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "tv")
                    .font(.system(size: 22))
                    .foregroundStyle(colors.textPrimary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 16, weight: selected ? .bold : .regular))
                        .trLabelScaling()
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                    if !saved {
                        Text(detail)
                            .font(TR.Font.caption)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(colors.accentText)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: TR.Size.sheetRow)
            .background {
                if selected {
                    shape.fill(colors.accent.opacity(0.16))
                        .overlay(shape.stroke(colors.accent, lineWidth: 1.5))
                        .shadow(color: colors.accent.opacity(0.35), radius: 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel(saved ? name : "\(name), ny på nätverket")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var codeField: some View {
        let colors = TR.Colors.of(scheme)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ange koden som visas på TV:n")
                .font(TR.Font.body)
                .foregroundStyle(colors.textSecondary)
            TextField("Sex tecken, t.ex. A1B2C3", text: $code)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .onChange(of: code) { value in
                    let filtered = value.uppercased().filter { $0.isLetter || $0.isNumber }
                    code = String(filtered.prefix(6))
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(colors.surfaceElevated, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous)
                        .stroke(code.count == 6 ? colors.accent : colors.line, lineWidth: code.count == 6 ? 2 : 1)
                )
                .accessibilityLabel("Kod, sex tecken, \(code.count) av 6 ifyllda")
        }
        .padding(.horizontal, 14)
        .offset(x: shake)
    }
}

/// Svep åt vänster på en rad för att glömma TV:n.
@MainActor
struct SwipeToForget<Content: View>: View {
    var onForget: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme
    @State private var offset: CGFloat = 0

    private let width: CGFloat = 88

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ZStack(alignment: .trailing) {
            Button {
                offset = 0
                onForget()
            } label: {
                Text("Glöm")
                    .font(TR.Font.body)
                    .foregroundStyle(.white)
                    .frame(width: width, height: TR.Size.sheetRow)
                    .background(colors.danger, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
            }
            .buttonStyle(TRPressStyle())
            .opacity(offset < -8 ? 1 : 0)
            .accessibilityLabel("Glöm TV:n")

            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard value.translation.width < 0 else { return }
                            offset = max(value.translation.width, -width)
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = value.translation.width < -44 ? -width : 0
                            }
                        }
                )
        }
        .accessibilityActions {
            Button("Glöm TV:n") { onForget() }
        }
    }
}

// MARK: - TV och anslutning (manuell adress, glöm parkoppling)

@MainActor
struct ConnectionPanel: View {
    @ObservedObject var connection: TVConnection
    var onClose: () -> Void
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var address = ""
    @State private var name = ""
    @State private var confirmForget = false

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "TV och anslutning", top: 110, onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PanelNotice(connection: connection)

                    VStack(spacing: 0) {
                        SettingsRow(icon: "dot.radiowaves.left.and.right",
                                    title: connection.status,
                                    showsChevron: false,
                                    accessory: {
                                        if connection.busy {
                                            ProgressView().controlSize(.small)
                                        }
                                    })
                        TRDivider()
                        SettingsRow(icon: "tv", title: "Välj TV", value: connection.tvName) {
                            openPanel(.chooseTV)
                        }
                    }
                    .trCard()

                    Text("MANUELL ADRESS")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.leading, 4)

                    VStack(spacing: 10) {
                        field("TV:ns namn", text: $name)
                        field("IP-adress eller värdnamn", text: $address, mono: true)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        TRPrimaryButton(title: "Anslut till sparad TV") { open(pair: false) }
                            .disabled(address.isEmpty || connection.busy || connection.needsCode)
                        Button { open(pair: true) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("Parkoppla med kod på TV:n")
                            }
                            .font(TR.Font.body)
                            .foregroundStyle(colors.accentText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(TRPressStyle())
                        .disabled(address.isEmpty || connection.busy || connection.needsCode)
                    }
                    .padding(14)
                    .trCard()

                    if connection.ready {
                        Button("Koppla från") { connection.disconnect() }
                            .font(TR.Font.body)
                            .foregroundStyle(colors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }

                    if connection.needsRepair {
                        TRPrimaryButton(title: "Parkoppla igen") { open(pair: true) }
                            .disabled(address.isEmpty || connection.busy)
                    }

                    Button("Glöm \(connection.tvName)") {
                        withAnimation(TRMotion.crossfade) { confirmForget = true }
                    }
                        .font(TR.Font.body)
                        .foregroundStyle(colors.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)

                    Text("TV:n kan behöva vara påslagen vid anslutning. Väcka från standby beror på TV:ns nätverksinställningar.")
                        .font(TR.Font.caption)
                        .foregroundStyle(colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 460)
        }
        .onAppear {
            address = connection.host
            name = connection.tvName
        }
        .overlay {
            if confirmForget {
                TRConfirmSheet(
                    title: "Glöm parkoppling med \(connection.tvName)?",
                    message: connection.host.isEmpty
                        ? "Du måste skriva in koden från TV:n igen för att ansluta."
                        : "Du måste skriva in koden från TV:n igen för att ansluta. (\(connection.host))",
                    confirmTitle: "Glöm \(connection.tvName)",
                    onConfirm: {
                        connection.forget()
                        withAnimation(TRMotion.crossfade) { confirmForget = false }
                    },
                    onCancel: {
                        withAnimation(TRMotion.crossfade) { confirmForget = false }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, mono: Bool = false) -> some View {
        let colors = TR.Colors.of(scheme)
        return TextField(title, text: text)
            .font(mono ? .system(size: 14).monospaced() : TR.Font.body)
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(colors.surfaceElevated, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous)
                    .stroke(colors.line, lineWidth: 1)
            )
    }

    private func open(pair: Bool) {
        connection.disconnect()
        connection.host = address
        connection.tvName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TCL 43P635" : name
        connection.connect(pair: pair)
    }
}

// MARK: - 123 Sifferknappar

@MainActor
struct NumberPadPanel: View {
    @ObservedObject var connection: TVConnection
    var onClose: () -> Void
    var openPanel: (Panel) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Sifferknappar", top: 180, onClose: onClose) {
            VStack(spacing: 12) {
                PanelNotice(connection: connection)
                if !connection.ready {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 17))
                            .foregroundStyle(colors.danger)
                        Text("Inte ansluten. Siffran skickades inte.")
                            .font(TR.Font.body)
                            .foregroundStyle(colors.textPrimary)
                        Spacer(minLength: 4)
                        Button {
                            openPanel(.chooseTV)
                        } label: {
                            Text("Anslut")
                                .font(TR.Font.body)
                                .foregroundStyle(colors.accentText)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(colors.accent.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(TRPressStyle())
                        .accessibilityLabel("Anslut till TV")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(colors.danger.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
                }

                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { column in
                                let number = row * 3 + column
                                numberKey("\(number)", label: "Siffra \(number)") {
                                    if let key = TVKey(rawValue: UInt64(number + 7)) { connection.press(key) }
                                }
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        TRKey(width: nil, height: 48, radius: TR.Radius.smallKey) {
                            connection.press(.delete)
                        } label: {
                            Image(systemName: "delete.left").font(.system(size: 20))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Radera")

                        numberKey("0", label: "Siffra 0") { connection.press(.zero) }

                        TRKey(width: nil, height: 48, radius: TR.Radius.smallKey) {
                            connection.press(.ok)
                        } label: {
                            Text("OK").font(.system(size: 21, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Bekräfta nummer")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
            }
            .padding(.top, 8)
        }
    }

    private func numberKey(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        TRKey(width: nil, height: 48, radius: TR.Radius.smallKey, action: action) {
            Text(title).font(TR.Font.numeric)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

// MARK: - Tangentbord

@MainActor
struct KeyboardPanel: View {
    @ObservedObject var connection: TVConnection
    var onClose: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Tangentbord", top: 150, onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                PanelNotice(connection: connection)

                Text("Markera först sökfältet eller textfältet på TV:n.")
                    .font(TR.Font.body)
                    .foregroundStyle(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // iPhones returtangent är medvetet inte kopplad: texten skickas
                // bara med Skicka text.
                TextField("Text till TV:n", text: $text, axis: .vertical)
                    .font(TR.Font.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1...4)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(colors.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(focused ? colors.accent : colors.line, lineWidth: focused ? 2 : 1)
                    )

                HStack(spacing: 8) {
                    TRKey(width: 56, height: 50, radius: 16) {
                        connection.press(.delete)
                    } label: {
                        Image(systemName: "delete.left").font(.system(size: 20))
                    }
                    .disabled(!connection.ready)
                    .accessibilityLabel("Radera ett tecken")

                    TRKey(width: 56, height: 50, radius: 16) {
                        connection.press(.enter)
                    } label: {
                        Image(systemName: "return").font(.system(size: 20))
                    }
                    .disabled(!connection.ready)
                    .accessibilityLabel("Enter eller sök")

                    TRPrimaryButton(title: "Skicka text") {
                        if connection.sendText(text) { text = "" }
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Hjälp

@MainActor
struct HelpPanel: View {
    var onClose: () -> Void
    var openPanel: (Panel) -> Void
    @Environment(\.colorScheme) private var scheme

    private let sections: [(String, [String])] = [
        ("Kom igång", [
            "Öppna TV och anslutning, välj din TCL och tryck på Parkoppla. Ange den sex tecken långa koden från TV:n.",
            "Tech Rabbit Remote behöver tillgång till lokalt nätverk på iPhone. TV:n och iPhone använder ditt befintliga wifi."
        ]),
        ("Knappar", [
            "OK väljer. Husknappen öppnar TV:ns hemskärm. Kugghjulet på fjärren öppnar TV:ns inställningar.",
            "123 öppnar sifferknappar. Tangentbordet skriver i ett aktivt textfält på TV:n. Stödet varierar mellan TV-appar.",
            "Tryck på mikrofonen för att börja tala och på stopp när du är klar. Inspelningen stannar automatiskt efter 15 sekunder.",
            "Kanal- och medieknappar fungerar där TV:n eller den öppna appen stöder dem. Av/på kan inte garanteras när TV:ns nätverk är avstängt i standby."
        ]),
        ("Om Tech Rabbit Remote", [
            "Version \(AppVersion.marketing). Utvecklad för din TCL 43P635. Funktionerna behöver verifieras på den riktiga TV:n.",
            "Anslutningen går direkt till TV:n på ditt lokala nätverk. Ingen analys, reklam eller prenumeration. Mikrofonljud skickas till TV:n bara under aktiv röstinmatning och sparas inte av appen. TV:ns röstassistent kan använda sin leverantörs onlinetjänster.",
            "Fristående app, inte en officiell TCL-produkt."
        ])
    ]

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Hjälp", top: 90, onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.0)
                                .font(.system(size: 18, weight: .heavy))
                                .trLabelScaling()
                                .foregroundStyle(colors.textPrimary)
                            ForEach(section.1, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(TR.Font.body)
                                    .foregroundStyle(colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trCard()
                    }
                    VStack(spacing: 0) {
                        SettingsRow(icon: "list.bullet.rectangle.portrait",
                                    title: "Anslutningslogg") {
                            openPanel(.log)
                        }
                    }
                    .trCard()

                    Button("Klart") { onClose() }
                        .font(TR.Font.body)
                        .foregroundStyle(colors.accentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 520)
        }
    }
}

// Anslutningsloggen: de senaste försöken, nyast först, med en kopieraknapp.
// Ingen privat nyckel och inget helt certifikat står i loggen, bara korta
// avtryck.
@MainActor
struct ConnectionLogPanel: View {
    var onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var entries: [ConnectionLogEntry] = []
    @State private var copied = false

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GlassSheet(title: "Anslutningslogg", top: 90, onClose: onClose) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(entries.isEmpty
                         ? "Inga försök loggade än."
                         : "\(entries.count) av \(ConnectionLog.limit) försök, nyast först.")
                        .font(TR.Font.caption)
                        .foregroundStyle(colors.textSecondary)
                    Spacer(minLength: 8)
                    Button {
                        UIPasteboard.general.string = ConnectionLog.shared.text
                        copied = true
                        TRHaptics.selection()
                    } label: {
                        Label(copied ? "Kopierad" : "Kopiera", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(TR.Font.caption)
                            .foregroundStyle(colors.accentText)
                            .padding(.horizontal, 14)
                            .frame(height: TR.Size.hitTargetMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TRPressStyle())
                    .accessibilityLabel(copied ? "Kopierad" : "Kopiera anslutningsloggen")
                }
                .padding(.horizontal, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if entries.isEmpty {
                            Text("Loggen fylls varje gång appen försöker ansluta.")
                                .font(TR.Font.body)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(entries.reversed()) { entry in
                            Text(entry.line)
                                .font(.system(size: 12).monospaced())
                                .foregroundStyle(colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .trCard()
                }
                .frame(maxHeight: 440)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .onAppear { entries = ConnectionLog.shared.entries }
        }
    }
}
