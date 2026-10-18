import Foundation
import Combine

struct DiscoveredTV: Identifiable {
    let id: String
    let name: String
    let host: String
}

/// Bonjour callbacks run on the main run loop.
final class TVDiscovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var devices: [DiscoveredTV] = []
    @Published var message = ""
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var searching = false

    func start() {
        guard !searching else { return }
        searching = true
        message = "Söker efter TV-apparater…"
        browser.delegate = self
        browser.searchForServices(ofType: "_androidtvremote2._tcp.", inDomain: "local.")
    }
    func stop() {
        browser.stop(); services.forEach { $0.stop() }
        services.removeAll(); devices.removeAll(); searching = false
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 8)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        devices.removeAll { $0.id == service.name }
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName else { return }
        devices.removeAll { $0.id == sender.name }
        devices.append(DiscoveredTV(id: sender.name, name: sender.name, host: host))
        message = "Välj din TV."
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        searching = false
        message = "Sökningen kunde inte starta. Tillåt lokalt nätverk i iPhones inställningar, eller ange TV:ns IP-adress."
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        message = "En TV hittades men adressen kunde inte läsas. Du kan ange IP-adressen."
    }
}
