import WidgetKit
import SwiftUI
import AppIntents
import AiMCore

// MARK: - App Intents (iOS 17): skickar kommandot utan att öppna appen.

@available(iOS 17.0, *)
struct SendKeyIntent: AppIntent {
    static var title: LocalizedStringResource = "Skicka till TV:n"
    static var description = IntentDescription("Skickar ett mediakommando till den TV som är vald i Tech Rabbit Remote.")
    /// Kommandot ska köras i bakgrunden, inte öppna appen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Tangent")
    var key: WidgetKeyChoice

    init() {}
    init(key: WidgetKeyChoice) { self.key = key }

    func perform() async throws -> some IntentResult {
        do {
            try await WidgetTVCommand.send(key.tvKey)
            WidgetState.lastFailed = false
        } catch {
            WidgetState.lastFailed = true
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, *)
enum WidgetKeyChoice: String, AppEnum {
    case rewind, play, fastForward

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tangent")
    static var caseDisplayRepresentations: [WidgetKeyChoice: DisplayRepresentation] = [
        .rewind: "Spola bakåt",
        .play: "Spela",
        .fastForward: "Spola framåt"
    ]

    var tvKey: TVKey {
        switch self {
        case .rewind: return .rewind
        case .play: return .play
        case .fastForward: return .fastForward
        }
    }
    var symbol: String {
        switch self {
        case .rewind: return "backward"
        case .play: return "play"
        case .fastForward: return "forward"
        }
    }
    var label: String {
        switch self {
        case .rewind: return "Spola bakåt"
        case .play: return "Spela"
        case .fastForward: return "Spola framåt"
        }
    }
}

enum WidgetState {
    /// Sattes senaste kommandot inte fram? Läses av vyn.
    static var lastFailed: Bool {
        get { Shared.defaults.bool(forKey: "widget.lastFailed") }
        set { Shared.defaults.set(newValue, forKey: "widget.lastFailed") }
    }
}

// MARK: - Tidslinje

struct RemoteEntry: TimelineEntry {
    let date: Date
    let tvName: String?
    let failed: Bool
}

struct RemoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteEntry {
        RemoteEntry(date: Date(), tvName: "TCL 43P635", failed: false)
    }
    func getSnapshot(in context: Context, completion: @escaping (RemoteEntry) -> Void) {
        completion(current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }
    private func current() -> RemoteEntry {
        RemoteEntry(date: Date(), tvName: Shared.activeTVName, failed: WidgetState.lastFailed)
    }
}

// MARK: - Vy enligt F2 med dark-tokens

struct RemoteWidgetView: View {
    var entry: RemoteEntry
    @Environment(\.widgetFamily) private var family

    private let text = Color(red: 0.95, green: 0.95, blue: 0.95)
    private let muted = Color(red: 0.60, green: 0.65, blue: 0.62)
    private let green = Color(red: 0.118, green: 0.839, blue: 0.235)
    private let keyTop = Color(red: 0.110, green: 0.165, blue: 0.125)
    private let keyBottom = Color(red: 0.067, green: 0.102, blue: 0.078)
    private let line = Color.white.opacity(0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack(spacing: 10) {
                Image(systemName: "appletvremote.gen4.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tv-kontroll")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(text)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.failed || entry.tvName == nil ? green.opacity(0.9) : muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                keyButton(.rewind)
                keyButton(.play)
                keyButton(.fastForward)
            }
            if family != .systemSmall { Spacer(minLength: 0) }
        }
        .padding(family == .systemSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Ett tryck utanför knapparna öppnar appen.
        .widgetURL(URL(string: "techrabbit://remote"))
    }

    private var subtitle: String {
        if entry.tvName == nil { return "Ingen TV vald" }
        if entry.failed { return "Inte ansluten" }
        return entry.tvName ?? ""
    }

    @ViewBuilder
    private func keyButton(_ choice: WidgetKeyChoiceShim) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: SendKeyIntent(key: choice.real)) {
                label(choice)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(choice.label)
        } else {
            label(choice)
        }
    }

    private func label(_ choice: WidgetKeyChoiceShim) -> some View {
        Image(systemName: choice.symbol)
            .font(.system(size: 16))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                LinearGradient(colors: [keyTop, keyBottom], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(line, lineWidth: 1)
            )
    }
}

/// Liten omväg så att vyn kan byggas även för iOS 16, där AppEnum saknas.
enum WidgetKeyChoiceShim: CaseIterable {
    case rewind, play, fastForward

    @available(iOS 17.0, *)
    var real: WidgetKeyChoice {
        switch self {
        case .rewind: return .rewind
        case .play: return .play
        case .fastForward: return .fastForward
        }
    }
    var symbol: String {
        switch self {
        case .rewind: return "backward"
        case .play: return "play"
        case .fastForward: return "forward"
        }
    }
    var label: String {
        switch self {
        case .rewind: return "Spola bakåt"
        case .play: return "Spela"
        case .fastForward: return "Spola framåt"
        }
    }
}

struct TechRabbitWidget: Widget {
    let kind = "TechRabbitRemoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemoteProvider()) { entry in
            if #available(iOS 17.0, *) {
                RemoteWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(red: 0.039, green: 0.102, blue: 0.055),
                                     Color(red: 0.020, green: 0.047, blue: 0.027)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
            } else {
                RemoteWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Tv-kontroll")
        .description("Styr TV:n direkt från hemskärmen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TechRabbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        TechRabbitWidget()
    }
}
