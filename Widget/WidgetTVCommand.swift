import Foundation
import Network
import Security
import CryptoKit
import AiMCore

/// Skickar en enda tangent till den aktiva TV:n och stänger. Widgeten
/// parkopplar aldrig: certifikatet måste stämma mot SavedTV.fingerprint.
final class WidgetTVCommand: NSObject, @unchecked Sendable {
    enum Failure: LocalizedError {
        case noActiveTV
        case certificateMismatch
        case timedOut
        case connection(String)

        var errorDescription: String? {
            switch self {
            case .noActiveTV: return "Ingen TV är vald i appen."
            case .certificateMismatch: return "TV:ns certifikat stämmer inte. Öppna appen."
            case .timedOut: return "TV:n svarade inte."
            case .connection(let text): return text
            }
        }
    }

    private var connection: NWConnection?
    private var frames = FrameBuffer()
    private var remote = RemoteExchange()
    private var finished = false
    private var continuation: CheckedContinuation<Void, Error>?
    private let queue = DispatchQueue(label: "se.aim.remote.widget")
    private let key: TVKey
    private let tv: SavedTV
    private var sentKey = false

    init(key: TVKey, tv: SavedTV) {
        self.key = key
        self.tv = tv
    }

    /// Ansluter, skickar tangenten och stänger. Hela förloppet har en
    /// tidsgräns på cirka 8 sekunder.
    static func send(_ key: TVKey, timeout: TimeInterval = 8) async throws {
        let store = SavedTVStore()
        guard let tv = store.active ?? store.all.first else { throw Failure.noActiveTV }
        let command = WidgetTVCommand(key: key, tv: tv)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await command.run() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                command.stop(with: Failure.timedOut)
                throw Failure.timedOut
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }

    private func run() async throws {
        let identity = try IdentityStore.loadOrCreate()
        guard let secIdentity = sec_identity_create(identity.identity) else {
            throw Failure.connection("Appens klientidentitet kunde inte öppnas.")
        }
        let pinned = tv.fingerprint

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation

            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_local_identity(tls.securityProtocolOptions, secIdentity)
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { [weak self] _, trust, complete in
                let trustRef = sec_trust_copy_ref(trust).takeRetainedValue()
                guard let chain = SecTrustCopyCertificateChain(trustRef) as? [SecCertificate],
                      let certificate = chain.first else {
                    complete(false)
                    self?.stop(with: Failure.certificateMismatch)
                    return
                }
                let raw = SecCertificateCopyData(certificate) as Data
                // Samma pinning som i appen. Ingen parkoppling här.
                guard Data(SHA256.hash(data: raw)) == pinned else {
                    complete(false)
                    self?.stop(with: Failure.certificateMismatch)
                    return
                }
                complete(true)
            }, queue)

            let tcp = NWProtocolTCP.Options()
            tcp.connectionTimeout = 6
            let parameters = NWParameters(tls: tls, tcp: tcp)
            let channel = NWConnection(
                host: NWEndpoint.Host(tv.host),
                port: NWEndpoint.Port(rawValue: 6466)!,
                using: parameters
            )
            connection = channel
            channel.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready: self.receive()
                case .failed(let error), .waiting(let error):
                    self.stop(with: Failure.connection(error.localizedDescription))
                case .cancelled:
                    self.stop(with: Failure.connection("Anslutningen stängdes."))
                default: break
                }
            }
            channel.start(queue: queue)
        }
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self, !self.finished else { return }
            do {
                if let data, !data.isEmpty {
                    for message in try self.frames.append(data) {
                        try self.handle(message)
                    }
                }
                if let error { throw error }
                if complete { throw Failure.connection("TV:n stängde anslutningen.") }
                if !self.finished { self.receive() }
            } catch {
                self.stop(with: error)
            }
        }
    }

    private func handle(_ message: Data) throws {
        let result = try remote.receive(message)
        result.replies.forEach { send($0) }
        for event in result.events {
            if case .started = event, !sentKey {
                sentKey = true
                send(RemoteExchange.key(key))
                // Kommandot är skickat. Stäng strax efter så att TV:n hinner läsa.
                queue.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.stop(with: nil) }
            }
        }
    }

    private func send(_ message: Data) {
        connection?.send(content: FrameBuffer.wrap(message), completion: .contentProcessed { _ in })
    }

    /// Avslutar en gång. nil betyder att kommandot gick fram.
    fileprivate func stop(with error: Error?) {
        queue.async { [weak self] in
            guard let self, !self.finished else { return }
            self.finished = true
            self.connection?.stateUpdateHandler = nil
            self.connection?.cancel()
            self.connection = nil
            let pending = self.continuation
            self.continuation = nil
            if let error { pending?.resume(throwing: error) } else { pending?.resume() }
        }
    }
}
