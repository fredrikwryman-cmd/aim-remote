import Foundation
import Network
import Security
import CryptoKit
import Combine
import AVFoundation
import AiMCore

@MainActor
final class TVConnection: ObservableObject {
    @Published private(set) var status = "Inte ansluten"
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var needsCode = false
    @Published private(set) var recording = false
    @Published private(set) var awaitingVoice = false
    @Published var notice: String?
    @Published var host = UserDefaults.standard.string(forKey: "tv.host") ?? ""
    @Published var tvName = UserDefaults.standard.string(forKey: "tv.name") ?? "TCL 43P635"

    private var connection: NWConnection?
    private var identity: ClientIdentity?
    private var peerKey: SecKey?
    private var peerCertificate: Data?
    private var frames = FrameBuffer()
    private var pairing = PairingExchange()
    private var remote = RemoteExchange()
    private var isPairing = false
    private var generation = UUID()
    private var deadline: DispatchWorkItem?
    private var voiceDeadline: DispatchWorkItem?
    private var voiceID: UInt64?
    private var audio = AudioCapture()
    private var audioBytes = Data()

    func connect(pair: Bool = false) {
        let clean = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, clean.count <= 253,
              clean.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !clean.contains("/"), !clean.contains("://") else {
            notice = "Välj din TV eller ange dess IP-adress."; return
        }
        disconnect()
        host = clean
        do {
            identity = try IdentityStore.loadOrCreate()
            let pin = try TrustStore.read(host: clean)
            if pin == nil && !pair {
                status = "TV:n behöver parkopplas"; notice = "Tryck på Parkoppla och ange koden som visas på TV:n."
                return
            }
            isPairing = pair
            pairing = PairingExchange(); remote = RemoteExchange(); frames = FrameBuffer()
            peerCertificate = nil; peerKey = nil
            busy = true; status = pair ? "Startar parkoppling…" : "Ansluter…"
            let token = generation
            let tls = NWProtocolTLS.Options()
            guard let identity, let secIdentity = sec_identity_create(identity.identity) else {
                throw AppFailure.message("Appens klientidentitet kunde inte öppnas.")
            }
            sec_protocol_options_set_local_identity(tls.securityProtocolOptions, secIdentity)
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { [weak self] _, trust, complete in
                let trustRef = sec_trust_copy_ref(trust).takeRetainedValue()
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token,
                          let chain = SecTrustCopyCertificateChain(trustRef) as? [SecCertificate],
                          let cert = chain.first, let key = SecCertificateCopyKey(cert) else {
                        complete(false); return
                    }
                    let raw = SecCertificateCopyData(cert) as Data
                    let fingerprint = Data(SHA256.hash(data: raw))
                    // Pairing authenticates this certificate through the on-screen code.
                    guard pair || pin == fingerprint else {
                        complete(false)
                        self.fail("TV:ns identitet har ändrats. Parkoppla på nytt om det är din TV.")
                        return
                    }
                    self.peerCertificate = raw; self.peerKey = key
                    complete(true)
                }
            }, .main)
            let tcp = NWProtocolTCP.Options()
            tcp.connectionTimeout = 12
            let parameters = NWParameters(tls: tls, tcp: tcp)
            let port = NWEndpoint.Port(rawValue: pair ? 6467 : 6466)!
            let channel = NWConnection(host: NWEndpoint.Host(clean), port: port, using: parameters)
            connection = channel
            channel.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    switch state {
                    case .ready:
                        if pair { self.send(self.pairing.request) }
                        self.receive(token: token)
                    case .failed(let error), .waiting(let error):
                        self.fail("TV:n kunde inte nås. Kontrollera att den är på. \(error.localizedDescription)")
                    case .cancelled: self.fail("Anslutningen stängdes.")
                    default: break
                    }
                }
            }
            channel.start(queue: .main)
            armDeadline(seconds: 15)
        } catch { fail(error.localizedDescription) }
    }

    func submit(code: String) {
        guard needsCode, let identity, let peerKey else { return }
        do {
            let digest = try IdentityStore.pairingDigest(code: code, clientKey: identity.publicKey, serverKey: peerKey)
            send(try pairing.submit(digest: digest))
            needsCode = false; busy = true; status = "Kontrollerar koden…"
            armDeadline(seconds: 15)
        } catch { notice = error.localizedDescription }
    }

    func press(_ key: TVKey) {
        guard ready else { notice = "Anslut till TV:n först."; return }
        send(RemoteExchange.key(key))
    }
    func sendText(_ value: String) -> Bool {
        guard ready else { notice = "Anslut till TV:n först."; return false }
        do { send(try remote.text(value)); return true }
        catch { notice = "Öppna ett textfält på TV:n först. Textinmatning stöds inte av alla TV-appar."; return false }
    }
    func forget() {
        disconnect(); TrustStore.forget(host: host)
        UserDefaults.standard.removeObject(forKey: "tv.host")
        status = "Parkopplingen är glömd på iPhone"
    }
    func reconnectIfSaved() {
        guard !ready, !busy, !host.isEmpty else { return }
        if (try? TrustStore.read(host: host)) != nil { connect() }
    }
    func disconnect() {
        endVoice()
        generation = UUID()
        deadline?.cancel(); deadline = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel(); connection = nil
        ready = false; busy = false; needsCode = false
        status = "Inte ansluten"
    }
    private func fail(_ message: String) {
        disconnect(); status = message; notice = message
    }
    private func armDeadline(seconds: Double) {
        deadline?.cancel()
        let token = generation
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.fail("TV:n svarade inte i tid. Försök ansluta igen.")
        }
        deadline = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }
    private func send(_ message: Data) {
        guard let connection else { return }
        let token = generation
        // Length and payload are one write, so rapid button presses cannot interleave frames.
        connection.send(content: FrameBuffer.wrap(message), completion: .contentProcessed { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.fail("Kommandot kunde inte skickas. \(error.localizedDescription)")
                }
            }
        })
    }
    private func receive(token: UUID) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                do {
                    if let data, !data.isEmpty {
                        for message in try self.frames.append(data) {
                            guard self.generation == token else { return }
                            try self.handle(message)
                        }
                    }
                    guard self.generation == token else { return }
                    if let error { throw error }
                    if complete { throw AppFailure.message("TV:n stängde anslutningen. Anslut igen eller parkoppla på nytt.") }
                    self.receive(token: token)
                } catch { self.fail(error.localizedDescription) }
            }
        }
    }
    private func handle(_ message: Data) throws {
        if isPairing {
            if let reply = try pairing.receive(message) { send(reply) }
            if pairing.phase == .waitingCode {
                needsCode = true; busy = false; status = "Ange koden som visas på TV:n"
                armDeadline(seconds: 120)
            } else if pairing.phase == .complete {
                guard let cert = peerCertificate else { throw AppFailure.message("TV-certifikatet saknas.") }
                try TrustStore.write(host: host, data: Data(SHA256.hash(data: cert)))
                UserDefaults.standard.set(host, forKey: "tv.host")
                UserDefaults.standard.set(tvName, forKey: "tv.name")
                connect()
            } else { armDeadline(seconds: 15) }
        } else {
            let result = try remote.receive(message)
            result.replies.forEach { send($0) }
            for event in result.events {
                switch event {
                case .started(let on):
                    ready = true; busy = false; status = on ? "Ansluten" : "Ansluten · TV i standby"
                    UserDefaults.standard.set(host, forKey: "tv.host")
                    UserDefaults.standard.set(tvName, forKey: "tv.name")
                case .voiceSession(let id):
                    if awaitingVoice { try beginAudio(id) }
                case .rejected: notice = "TV:n kunde inte utföra det senaste kommandot."
                case .textAvailable: break
                }
            }
            if ready { armDeadline(seconds: 60) }
        }
    }

    func toggleVoice() async {
        if recording || awaitingVoice { endVoice(); return }
        guard ready, remote.features & 8 != 0 else {
            notice = "TV:n har inte aktiverat röstinmatning för den här anslutningen."; return
        }
        let token = generation
        let allowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == token, ready else { return }
        guard allowed else { notice = "Tillåt mikrofon för Tech Rabbit Remote i iPhones inställningar."; return }
        awaitingVoice = true
        send(RemoteExchange.key(.search))
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.awaitingVoice else { return }
            self.endVoice(); self.notice = "TV:n startade ingen röstsession. Prova igen eller använd tangentbordet."
        }
        voiceDeadline = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }
    private func beginAudio(_ id: UInt64) throws {
        voiceDeadline?.cancel()
        voiceID = id; audioBytes.removeAll(); awaitingVoice = false
        send(RemoteExchange.voiceBegin(id))
        audio.onPCM = { [weak self] bytes in
            guard let self, self.recording, let id = self.voiceID else { return }
            self.audioBytes.append(bytes)
            while self.audioBytes.count >= 8192 {
                self.send(RemoteExchange.voiceChunk(id, Data(self.audioBytes.prefix(8192))))
                self.audioBytes.removeFirst(8192)
            }
        }
        audio.onFailure = { [weak self] message in self?.endVoice(); self?.notice = message }
        do { try audio.start(); recording = true }
        catch { endVoice(); throw error }
        let item = DispatchWorkItem { [weak self] in self?.endVoice() }
        voiceDeadline = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }
    func endVoice() {
        voiceDeadline?.cancel(); voiceDeadline = nil
        audio.stop()
        if let id = voiceID {
            if !audioBytes.isEmpty {
                audioBytes.append(Data(repeating: 0, count: max(0, 8192 - audioBytes.count)))
                send(RemoteExchange.voiceChunk(id, audioBytes))
            }
            send(RemoteExchange.voiceEnd(id))
        }
        voiceID = nil; audioBytes.removeAll(); recording = false; awaitingVoice = false
    }
}

