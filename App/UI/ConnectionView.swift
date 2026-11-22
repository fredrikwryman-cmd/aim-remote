import SwiftUI

// Felmeddelanden syns inne i den panel som är öppen, inte som systemdialog.
@MainActor
struct NoticeBanner: View {
    @ObservedObject var connection: TVConnection
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        if let notice = connection.notice {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.danger)
                Text(notice)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button { connection.notice = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dölj meddelandet")
            }
            .padding(.leading, 14)
            .padding(.vertical, 4)
            .background(palette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

// Kort som samlar en grupp rader i panelerna.
private struct PanelCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(palette.textSecondary)
                    .padding(.leading, 18)
            }
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(radius: 26)
        }
    }
}

@MainActor
struct ConnectionView: View {
    @ObservedObject var connection: TVConnection
    @StateObject private var discovery = TVDiscovery()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var address = ""
    @State private var code = ""
    @State private var name = "TCL 43P635"
    @State private var confirmForget = false

    var body: some View {
        let palette = scheme.palette
        NavigationStack {
            ZStack {
                palette.sheet.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        NoticeBanner(connection: connection)

                        PanelCard {
                            HStack(spacing: 10) {
                                if connection.busy {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Circle()
                                        .fill(connection.ready ? palette.success : palette.textMuted)
                                        .frame(width: 8, height: 8)
                                        .accessibilityHidden(true)
                                }
                                Text(connection.status)
                                    .font(.system(size: 17))
                                    .foregroundStyle(palette.textPrimary)
                                Spacer(minLength: 4)
                            }
                            if connection.ready {
                                Button("Koppla från") { connection.disconnect() }
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(palette.danger)
                            }
                        }

                        if connection.needsCode {
                            PanelCard(title: "Ange koden på TV:n") {
                                TextField("Sex tecken, t.ex. A1B2C3", text: $code)
                                    .font(.system(size: 17))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .keyboardType(.asciiCapable)
                                    .textContentType(.oneTimeCode)
                                    .submitLabel(.done)
                                    .onSubmit { connection.submit(code: code) }
                                    .padding(.horizontal, 14)
                                    .frame(height: 52)
                                    .background(palette.surfaceElevated.opacity(scheme == .dark ? 0.25 : 1),
                                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(palette.separator, lineWidth: 1)
                                    )
                                PrimaryButton(title: "Bekräfta kod") { connection.submit(code: code) }
                                    .disabled(code.count != 6)
                                Text("Koden visas på TV-skärmen när Tech Rabbit Remote begär parkoppling.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }

                        PanelCard(title: "Din TV") {
                            field("TV:ns namn", text: $name)
                            field("IP-adress eller värdnamn", text: $address, mono: true)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                            PrimaryButton(title: "Anslut till sparad TV") { open(pair: false) }
                                .disabled(address.isEmpty || connection.busy || connection.needsCode)
                            Button {
                                code = ""
                                open(pair: true)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                    Text("Parkoppla med kod på TV:n")
                                }
                                .font(.system(size: 17))
                                .foregroundStyle(palette.accentText)
                            }
                            .buttonStyle(.plain)
                            .disabled(address.isEmpty || connection.busy || connection.needsCode)
                        }

                        PanelCard(title: "TV-apparater i närheten") {
                            ForEach(discovery.devices) { device in
                                Button {
                                    address = device.host
                                    name = device.name
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "tv")
                                            .font(.system(size: 20))
                                            .foregroundStyle(palette.iconPrimary)
                                        Text(device.name)
                                            .font(.system(size: 17))
                                            .foregroundStyle(palette.textPrimary)
                                        Spacer(minLength: 4)
                                        if address == device.host {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(palette.accentText)
                                        }
                                    }
                                    .frame(height: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(address == device.host ? .isSelected : [])
                            }
                            Text(discovery.message)
                                .font(.system(size: 13))
                                .foregroundStyle(palette.textSecondary)
                            if discovery.devices.isEmpty {
                                Text("Om TV:n inte visas kan du skriva dess IP-adress ovan. Adressen finns i TV:ns nätverksinställningar.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Button {
                                discovery.stop()
                                discovery.start()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .semibold))
                                    Text("Sök igen")
                                }
                                .font(.system(size: 17))
                                .foregroundStyle(palette.accentText)
                            }
                            .buttonStyle(.plain)
                        }

                        PanelCard {
                            Button("Glöm parkoppling") { confirmForget = true }
                                .font(.system(size: 17))
                                .foregroundStyle(palette.danger)
                            Text("TV:n kan behöva vara påslagen vid anslutning. Väcka från standby beror på TV:ns nätverksinställningar.")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("TV och anslutning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(connection.busy || connection.needsCode ? "Avbryt" : "Klart") {
                        if connection.busy || connection.needsCode { connection.disconnect() }
                        dismiss()
                    }
                    .foregroundStyle(palette.accentText)
                }
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
        .onAppear {
            address = connection.host
            name = connection.tvName
            discovery.start()
        }
        .onDisappear { discovery.stop() }
        .interactiveDismissDisabled(connection.busy || connection.needsCode)
    }

    private func field(_ title: String, text: Binding<String>, mono: Bool = false) -> some View {
        let palette = scheme.palette
        return TextField(title, text: text)
            .font(mono ? .system(size: 14).monospaced() : .system(size: 17))
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(palette.surfaceElevated.opacity(scheme == .dark ? 0.25 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.separator, lineWidth: 1)
            )
    }

    private func open(pair: Bool) {
        connection.disconnect()
        connection.host = address
        connection.tvName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TCL 43P635" : name
        connection.connect(pair: pair)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let palette = scheme.palette
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.connectText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(palette.accentSubtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.38)
    }
}

@MainActor
struct KeyboardView: View {
    @ObservedObject var connection: TVConnection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let palette = scheme.palette
        NavigationStack {
            ZStack {
                palette.sheet.ignoresSafeArea()
                VStack(spacing: 14) {
                    NoticeBanner(connection: connection)
                    Text("Markera först sökfältet eller textfältet på TV:n.")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Text till TV:n", text: $text, axis: .vertical)
                        .font(.system(size: 17))
                        .lineLimit(1...5)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { if !trimmed.isEmpty, connection.sendText(text) { text = "" } }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(palette.surfaceElevated.opacity(scheme == .dark ? 0.25 : 1),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(focused ? palette.accent : palette.separator, lineWidth: focused ? 2 : 1)
                        )

                    HStack(spacing: 8) {
                        Button { connection.press(.delete) } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 20))
                                .frame(width: 56, height: 50)
                        }
                        .buttonStyle(GlassButtonStyle(radius: 16))
                        .disabled(!connection.ready)
                        .accessibilityLabel("Radera ett tecken")

                        Button { connection.press(.enter) } label: {
                            Image(systemName: "return")
                                .font(.system(size: 20))
                                .frame(width: 56, height: 50)
                        }
                        .buttonStyle(GlassButtonStyle(radius: 16))
                        .disabled(!connection.ready)
                        .accessibilityLabel("Enter eller sök")

                        Button {
                            if connection.sendText(text) { text = "" }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane")
                                Text("Skicka text")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.connectText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(palette.accentSubtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmed.isEmpty)
                        .opacity(trimmed.isEmpty ? 0.38 : 1)
                        .accessibilityLabel("Skicka text till TV:n")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 15)
                .padding(.top, 12)
            }
            .navigationTitle("Tangentbord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }.foregroundStyle(palette.accentText)
                }
            }
        }
        .onAppear { focused = true }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
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
        let palette = scheme.palette
        NavigationStack {
            ZStack {
                palette.sheet.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(sections, id: \.0) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.0)
                                    .font(.system(size: 22, weight: .bold))
                                    .tracking(-0.3)
                                    .foregroundStyle(palette.textPrimary)
                                ForEach(section.1, id: \.self) { paragraph in
                                    Text(paragraph)
                                        .font(.system(size: 17))
                                        .foregroundStyle(palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardSurface(radius: 26)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Hjälp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }
                        .foregroundStyle(palette.accentText)
                        .accessibilityLabel("Klart")
                }
            }
        }
    }
}
