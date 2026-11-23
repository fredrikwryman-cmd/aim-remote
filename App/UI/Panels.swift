import SwiftUI
import AiMCore

// MARK: - R04 Välj TV

@MainActor
struct ChooseTVPanel: View {
    @ObservedObject var connection: TVConnection
    var onClose: () -> Void

    @StateObject private var discovery = TVDiscovery()
    @Environment(\.colorScheme) private var scheme
    @State private var selectedNewHost = ""
    @State private var code = ""
    @State private var forgetTarget: SavedTV?

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
                    Text("Inga TV-apparater hittades på nätverket")
                        .font(TR.Font.row)
                        .foregroundStyle(colors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    TRPrimaryButton(title: "Sök igen") {
                        discovery.stop()
                        discovery.start()
                    }
                    .padding(.horizontal, 14)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(connection.savedTVs.enumerated()), id: \.element.id) { index, tv in
                                if index > 0 { TRDivider() }
                                SwipeToForget(onForget: { forgetTarget = tv }) {
                                    row(
                                        name: tv.name,
                                        detail: tv.host,
                                        selected: connection.activeTVID == tv.id,
                                        saved: true
                                    ) {
                                        selectedNewHost = ""
                                        connection.select(tv)
                                    }
                                }
                            }
                            if !discovered.isEmpty {
                                Text("NYA PÅ NÄTVERKET")
                                    .font(.custom("Archivo-SemiBold", size: 12))
                                    .tracking(0.3)
                                    .foregroundStyle(colors.muted)
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
                                        selectedNewHost = device.host
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .padding(.top, 6)

                    if connection.needsCode {
                        codeField.padding(.top, 10)
                    }

                    if connection.needsRepair {
                        Text("TV:n visade ett annat certifikat än den sparade. Parkoppla igen om det är din TV.")
                            .font(TR.Font.caption)
                            .foregroundStyle(colors.power)
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
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
        .onChange(of: connection.ready) { ready in
            if ready { onClose() }
        }
        .confirmationDialog(
            "Glöm \(forgetTarget?.name ?? "TV:n")?",
            isPresented: Binding(get: { forgetTarget != nil }, set: { if !$0 { forgetTarget = nil } }),
            titleVisibility: .visible,
            presenting: forgetTarget
        ) { tv in
            Button("Glöm \(tv.name)", role: .destructive) { connection.forget(id: tv.id) }
            Button("Avbryt", role: .cancel) { }
        } message: { tv in
            Text("\(tv.host). Tech Rabbit Remote kan inte styra den här TV:n förrän du parkopplar igen.")
        }
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
                    .foregroundStyle(colors.text)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.custom(selected ? "Archivo-Bold" : "Archivo-Regular", size: 16))
                        .trLabelScaling()
                        .foregroundStyle(colors.text)
                        .lineLimit(1)
                    if !saved {
                        Text(detail)
                            .font(TR.Font.caption)
                            .foregroundStyle(colors.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(colors.greenText)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: TR.Size.sheetRow)
            .background {
                if selected {
                    shape.fill(Color(hex: 0x1ED63C, opacity: 0.14))
                        .overlay(shape.stroke(colors.green, lineWidth: 1.5))
                        .shadow(color: colors.green.opacity(0.35), radius: 8)
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
                .font(TR.Font.rowValue)
                .foregroundStyle(colors.muted)
            TextField("Sex tecken, t.ex. A1B2C3", text: $code)
                .font(.custom("Archivo-SemiBold", size: 20))
                .foregroundStyle(colors.text)
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
                .background(colors.keyFlat, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous)
                        .stroke(code.count == 6 ? colors.green : colors.line, lineWidth: code.count == 6 ? 2 : 1)
                )
                .accessibilityLabel("Kod, sex tecken, \(code.count) av 6 ifyllda")
        }
        .padding(.horizontal, 14)
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
                    .font(TR.Font.status)
                    .foregroundStyle(.white)
                    .frame(width: width, height: TR.Size.sheetRow)
                    .background(colors.power, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
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
                        .font(.custom("Archivo-SemiBold", size: 13))
                        .tracking(0.3)
                        .foregroundStyle(colors.muted)
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
                            .font(TR.Font.row)
                            .foregroundStyle(colors.greenText)
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
                            .font(TR.Font.row)
                            .foregroundStyle(colors.power)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }

                    if connection.needsRepair {
                        TRPrimaryButton(title: "Parkoppla igen") { open(pair: true) }
                            .disabled(address.isEmpty || connection.busy)
                    }

                    Button("Glöm \(connection.tvName)") { confirmForget = true }
                        .font(TR.Font.row)
                        .foregroundStyle(colors.power)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)

                    Text("TV:n kan behöva vara påslagen vid anslutning. Väcka från standby beror på TV:ns nätverksinställningar.")
                        .font(TR.Font.caption)
                        .foregroundStyle(colors.muted)
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
        .confirmationDialog(
            "Glöm parkoppling med \(connection.tvName)?",
            isPresented: $confirmForget,
            titleVisibility: .visible
        ) {
            Button("Glöm \(connection.tvName)", role: .destructive) { connection.forget() }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("\(connection.host). Tech Rabbit Remote kan inte styra den här TV:n förrän du parkopplar igen.")
        }
    }

    private func field(_ title: String, text: Binding<String>, mono: Bool = false) -> some View {
        let colors = TR.Colors.of(scheme)
        return TextField(title, text: text)
            .font(mono ? .system(size: 14).monospaced() : TR.Font.row)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(colors.keyFlat, in: RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous))
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
                            .foregroundStyle(colors.power)
                        Text("Inte ansluten. Siffran skickades inte.")
                            .font(TR.Font.rowValue)
                            .foregroundStyle(colors.text)
                        Spacer(minLength: 4)
                        Button {
                            openPanel(.chooseTV)
                        } label: {
                            Text("Anslut")
                                .font(TR.Font.status)
                                .foregroundStyle(colors.greenText)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(colors.pill, in: Capsule())
                        }
                        .buttonStyle(TRPressStyle())
                        .accessibilityLabel("Anslut till TV")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(colors.power.opacity(0.08),
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
                            Text("OK").font(TR.Font.ok)
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
            Text(title).font(TR.Font.number)
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
                    .font(TR.Font.rowValue)
                    .foregroundStyle(colors.muted)
                    .fixedSize(horizontal: false, vertical: true)

                // iPhones returtangent är medvetet inte kopplad: texten skickas
                // bara med Skicka text.
                TextField("Text till TV:n", text: $text, axis: .vertical)
                    .font(TR.Font.row)
                    .foregroundStyle(colors.text)
                    .lineLimit(1...4)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(colors.keyFlat, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(focused ? colors.green : colors.line, lineWidth: focused ? 2 : 1)
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
            "Testversion 0.1.0. Utvecklad för din TCL 43P635. Funktionerna behöver verifieras på den riktiga TV:n.",
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
                                .font(.custom("Archivo-ExtraBold", size: 18))
                                .trLabelScaling()
                                .foregroundStyle(colors.text)
                            ForEach(section.1, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(TR.Font.rowValue)
                                    .foregroundStyle(colors.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trCard()
                    }
                    Button("Klart") { onClose() }
                        .font(TR.Font.row)
                        .foregroundStyle(colors.greenText)
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
