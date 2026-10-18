import SwiftUI

@MainActor
struct ConnectionView: View {
    @ObservedObject var connection: TVConnection
    @StateObject private var discovery = TVDiscovery()
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var code = ""
    @State private var name = "TCL 43P635"
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { if connection.busy { ProgressView() }; Text(connection.status) }
                    if connection.ready { Button("Koppla från", role: .destructive) { connection.disconnect() } }
                } header: { Text("Anslutning") }

                if connection.needsCode {
                    Section("Kod på TV:n") {
                        TextField("Sex tecken, t.ex. A1B2C3", text: $code)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .keyboardType(.asciiCapable).submitLabel(.go)
                            .onSubmit { connection.submit(code: code) }
                        Button("Bekräfta kod") { connection.submit(code: code) }.disabled(code.count != 6)
                        Text("Koden visas på TV-skärmen när AiM Remote begär parkoppling.").font(.footnote)
                    }
                }

                Section("Din TV") {
                    TextField("TV:ns namn", text: $name)
                    TextField("IP-adress eller värdnamn", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Button("Anslut till sparad TV") { open(pair: false) }
                        .disabled(address.isEmpty || connection.busy || connection.needsCode)
                    Button("Parkoppla med kod på TV:n") { code = ""; open(pair: true) }
                        .disabled(address.isEmpty || connection.busy || connection.needsCode)
                }
                Section("TV-apparater i närheten") {
                    ForEach(discovery.devices) { device in
                        Button {
                            address = device.host
                            name = device.name
                        } label: {
                            HStack { Image(systemName: "tv"); Text(device.name); Spacer(); if address == device.host { Image(systemName: "checkmark") } }
                        }
                    }
                    Text(discovery.message).font(.footnote).foregroundStyle(.secondary)
                    if discovery.devices.isEmpty {
                        Text("Om TV:n inte visas kan du skriva dess IP-adress ovan. Adressen finns i TV:ns nätverksinställningar.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Sök igen") { discovery.stop(); discovery.start() }
                }
                Section {
                    Button("Glöm sparad parkoppling", role: .destructive) { confirmForget = true }
                    Text("TV:n kan behöva vara påslagen vid anslutning. Väcka från standby beror på TV:ns nätverksinställningar.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .tint(Theme.green).navigationTitle("TV och anslutning").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(connection.busy || connection.needsCode ? "Avbryt" : "Klart") {
                        if connection.busy || connection.needsCode { connection.disconnect() }
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Glöm parkopplingen på iPhone?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("Glöm parkoppling", role: .destructive) { connection.forget() }
            }
            .alert("AiM Remote", isPresented: Binding(get: { connection.notice != nil }, set: { if !$0 { connection.notice = nil } })) {
                Button("OK") { connection.notice = nil }
            } message: { Text(connection.notice ?? "") }
        }
        .onAppear { address = connection.host; name = connection.tvName; discovery.start() }
        .onDisappear { discovery.stop() }
        .interactiveDismissDisabled(connection.busy || connection.needsCode)
    }
    private func open(pair: Bool) {
        connection.disconnect()
        connection.host = address
        connection.tvName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TCL 43P635" : name
        connection.connect(pair: pair)
    }
}

@MainActor
struct KeyboardView: View {
    @ObservedObject var connection: TVConnection
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Markera först sökfältet eller textfältet på TV:n.")
                    TextField("Text till TV:n", text: $text, axis: .vertical)
                        .lineLimit(1...5).focused($focused).autocorrectionDisabled()
                    Button("Skicka text") { if connection.sendText(text) { text = "" } }.disabled(text.isEmpty)
                    Button("Enter / sök") { connection.press(.enter) }
                    Button("Radera ett tecken") { connection.press(.delete) }
                }
            }
            .navigationTitle("Tangentbord").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klart") { dismiss() } } }
            .alert("AiM Remote", isPresented: Binding(get: { connection.notice != nil }, set: { if !$0 { connection.notice = nil } })) {
                Button("OK") { connection.notice = nil }
            } message: { Text(connection.notice ?? "") }
        }.tint(Theme.green).onAppear { focused = true }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Kom igång") {
                    Text("Öppna TV och anslutning, välj din TCL och tryck på Parkoppla. Ange den sex tecken långa koden från TV:n.")
                    Text("AiM Remote behöver tillgång till lokalt nätverk på iPhone. TV:n och iPhone använder ditt befintliga wifi.")
                }
                Section("Knappar") {
                    Text("OK väljer. Husknappen öppnar TV:ns hemskärm. Kugghjulet på fjärren öppnar TV:ns inställningar.")
                    Text("123 öppnar sifferknappar. Tangentbordet skriver i ett aktivt textfält på TV:n. Stödet varierar mellan TV-appar.")
                    Text("Tryck på mikrofonen för att börja tala och på stopp när du är klar. Inspelningen stannar automatiskt efter 15 sekunder.")
                    Text("Kanal- och medieknappar fungerar där TV:n eller den öppna appen stöder dem. Av/på kan inte garanteras när TV:ns nätverk är avstängt i standby.")
                }
                Section("Om AiM Remote") {
                    Text("Testversion 0.1.0. Utvecklad för din TCL 43P635. Funktionerna behöver verifieras på den riktiga TV:n.")
                    Text("Anslutningen går direkt till TV:n på ditt lokala nätverk. Ingen analys, reklam eller prenumeration. Mikrofonljud skickas till TV:n bara under aktiv röstinmatning och sparas inte av appen. TV:ns röstassistent kan använda sin leverantörs onlinetjänster.")
                    Text("Fristående app, inte en officiell TCL-produkt.")
                }
            }
            .navigationTitle("Hjälp").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klart") { dismiss() } } }
        }.tint(Theme.green)
    }
}
