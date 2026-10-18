import SwiftUI
import AiMCore
import UIKit

private enum Panel: String, Identifiable {
    case connection, numbers, keyboard, help
    var id: String { rawValue }
}

@MainActor
struct RemoteRoot: View {
    @ObservedObject var connection: TVConnection
    @AppStorage("haptics") private var haptics = true
    @State private var settings = false
    @State private var panel: Panel?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if settings {
                settingsView
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        remoteView(width: min(geometry.size.width - 36, 430))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sheet(item: $panel) { selection in
            switch selection {
            case .connection: ConnectionView(connection: connection)
            case .numbers: numberPad
            case .keyboard: KeyboardView(connection: connection)
            case .help: HelpView()
            }
        }
        .alert("AiM Remote", isPresented: Binding(get: { connection.notice != nil && panel == nil }, set: { if !$0 { connection.notice = nil } })) {
            Button("OK") { connection.notice = nil }
        } message: { Text(connection.notice ?? "") }
    }

    private func tap(_ key: TVKey) {
        if haptics && connection.ready { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        connection.press(key)
    }
    private func key(_ symbol: String, _ title: String, _ code: TVKey, width: CGFloat, height: CGFloat = 52) -> some View {
        Button { tap(code) } label: {
            Image(systemName: symbol).font(.system(size: 25, weight: .regular))
                .frame(width: width, height: height)
        }
        .buttonStyle(RemoteButtonStyle())
        .accessibilityLabel(title)
    }
    private func plain(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 28, weight: .regular))
                .frame(minWidth: 48, minHeight: 48)
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
    private func rocker(_ title: String, up: TVKey, down: TVKey, width: CGFloat) -> some View {
        VStack(spacing: 6) {
            key("chevron.up", "\(title) upp", up, width: width - 10)
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            key("chevron.down", "\(title) ned", down, width: width - 10)
        }
        .padding(5)
        .overlay(RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.20), lineWidth: 1))
    }

    private func remoteView(width: CGFloat) -> some View {
        let small = (width - 34) / 4
        let pad = min(90.0, width * 0.24)
        return VStack(spacing: 22) {
            HStack {
                plain("power", "Av eller på") { tap(.power) }.foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 5) {
                    Text(connection.tvName).font(.title3.weight(.medium)).lineLimit(1)
                    Text("AiM Remote").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 4)
                plain("tv", "Välj eller anslut TV") { panel = .connection }
            }
            Button { panel = .connection } label: {
                HStack(spacing: 7) {
                    if connection.busy { ProgressView().controlSize(.small) }
                    else { Circle().fill(connection.ready ? Theme.green : Theme.muted).frame(width: 6, height: 6) }
                    Text(connection.status).font(.caption).lineLimit(2)
                    Spacer()
                    if !connection.ready { Text("Anslut").foregroundStyle(Theme.green) }
                }.foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }.buttonStyle(.plain).accessibilityLabel("\(connection.status). Välj anslutning")

            HStack(alignment: .center, spacing: 8) {
                rocker("Kanal", up: .channelUp, down: .channelDown, width: small)
                VStack(spacing: 35) {
                    key("list.bullet.rectangle", "TV-guide", .guide, width: small)
                    key("gearshape", "TV-inställningar", .settings, width: small)
                }
                VStack(spacing: 35) {
                    key("speaker.slash", "Stäng av eller sätt på ljud", .mute, width: small)
                    Button { panel = .keyboard } label: {
                        Image(systemName: "keyboard").font(.system(size: 24)).frame(width: small, height: 52)
                    }.buttonStyle(RemoteButtonStyle()).accessibilityLabel("Skriv på TV:n")
                }
                rocker("Volym", up: .volumeUp, down: .volumeDown, width: small)
            }

            Grid(horizontalSpacing: (width - pad * 3) / 2, verticalSpacing: 18) {
                GridRow {
                    Button("123") { panel = .numbers }.font(.title2).frame(width: pad, height: pad).accessibilityLabel("Sifferknappar")
                    key("chevron.up", "Upp", .up, width: pad, height: pad)
                    Button { Task { await connection.toggleVoice() } } label: {
                        Image(systemName: connection.recording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(connection.recording ? .red : .white)
                            .frame(width: pad, height: pad)
                    }.accessibilityLabel(connection.recording ? "Stoppa mikrofon" : "Starta röstinmatning")
                }
                GridRow {
                    key("chevron.left", "Vänster", .left, width: pad, height: pad)
                    Button { tap(.ok) } label: {
                        Text("OK").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: pad, height: pad)
                    }.buttonStyle(RemoteButtonStyle()).accessibilityLabel("OK, välj")
                    key("chevron.right", "Höger", .right, width: pad, height: pad)
                }
                GridRow {
                    plain("arrow.left", "Tillbaka") { tap(.back) }.frame(width: pad, height: pad)
                    key("chevron.down", "Ned", .down, width: pad, height: pad)
                    plain("house", "Hem") { tap(.home) }.frame(width: pad, height: pad)
                }
            }.buttonStyle(.plain).foregroundStyle(.white)

            if connection.recording || connection.awaitingVoice {
                Text(connection.recording ? "Lyssnar… tryck på stopp när du är klar" : "Väntar på TV:ns mikrofon…")
                    .font(.caption).foregroundStyle(Theme.green)
            }
            HStack(spacing: 8) {
                key("backward", "Spola bakåt", .rewind, width: small)
                key("play", "Spela", .play, width: small)
                key("pause", "Pausa", .pause, width: small)
                key("forward", "Spola framåt", .fastForward, width: small)
            }
        }.frame(width: width)
    }

    private var tabBar: some View {
        HStack {
            tab("Fjärr", icon: "appletvremote.gen4.fill", selected: !settings) { settings = false }
            tab("Inställningar", icon: "slider.horizontal.3", selected: settings) { settings = true }
        }
        .padding(.top, 13).padding(.bottom, 8)
        .background(Theme.background)
    }
    private func tab(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 24)); Text(title).font(.caption) }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selected ? Theme.green : Theme.muted)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var settingsView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Inställningar").font(.title2).padding(.top, 24)
                HStack(spacing: 18) {
                    Image(systemName: "appletvremote.gen4.fill").font(.system(size: 36)).foregroundStyle(Theme.green)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AiM Remote").font(.title2.weight(.semibold))
                        Text("Din TV. Din kontroll.").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }
                .padding(26).frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Theme.top, Theme.bottom], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 26))
                VStack(spacing: 0) {
                    settingsRow("TV och anslutning", detail: connection.ready ? "Ansluten" : "Välj TV") { panel = .connection }
                    Divider()
                    settingsRow("Hjälp", detail: "") { panel = .help }
                    Divider()
                    Toggle("Knappvibration", isOn: $haptics).tint(Theme.green).padding(.vertical, 22)
                }
                Text("v0.1.0 · Testversion").font(.footnote).foregroundStyle(Theme.muted)
            }.padding(.horizontal, 24).frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
        }
    }
    private func settingsRow(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Text(detail).foregroundStyle(Theme.muted); Image(systemName: "chevron.right") }
                .padding(.vertical, 22)
        }.buttonStyle(.plain)
    }
    private var numberPad: some View {
        NavigationStack {
            VStack(spacing: 18) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(1...9, id: \.self) { n in
                        Button("\(n)") { if let key = TVKey(rawValue: UInt64(n + 7)) { tap(key) } }
                            .font(.title).frame(maxWidth: .infinity, minHeight: 70).buttonStyle(RemoteButtonStyle())
                    }
                    Button { tap(.delete) } label: { Image(systemName: "delete.left").frame(maxWidth: .infinity, minHeight: 70) }
                        .buttonStyle(RemoteButtonStyle()).accessibilityLabel("Radera")
                    Button("0") { tap(.zero) }.font(.title).frame(maxWidth: .infinity, minHeight: 70).buttonStyle(RemoteButtonStyle())
                    Button("OK") { tap(.ok) }.frame(maxWidth: .infinity, minHeight: 70).buttonStyle(RemoteButtonStyle())
                }.padding(24)
                Spacer()
            }
            .background(Theme.background).navigationTitle("Sifferknappar")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klart") { panel = nil } } }
        }.presentationDetents([.medium, .large])
    }
}
