import Foundation
import Observation

/// Gekoppeltes Gerät; das Token geht nur einmal bei der Kopplung an das Gerät.
nonisolated struct PairedDevice: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let token: String
    let pairedAt: Date
}

/// Kopplung per 4-stelliger PIN: Die PIN steht in CueView, das Gerät bekommt dafür ein Token.
/// Nach zu vielen Fehlversuchen ist die Kopplung kurz gesperrt. Geräte liegen je Rechner in den UserDefaults.
@Observable
final class RemotePairing {
    static let maxFailedAttempts = 5
    static let lockDuration: TimeInterval = 60
    private static let storageKey = "remotePairedDevices"

    enum PairingError: Error, Equatable {
        case wrongPIN
        case locked(until: Date)
    }

    private(set) var pin: String
    private(set) var devices: [PairedDevice] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let makePIN: () -> String
    @ObservationIgnored private var failedAttempts = 0
    @ObservationIgnored private var lockedUntil: Date?

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        makePIN: @escaping () -> String = { String(format: "%04d", Int.random(in: 0...9999)) }
    ) {
        self.defaults = defaults
        self.now = now
        self.makePIN = makePIN
        pin = makePIN()
        devices = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode([PairedDevice].self, from: $0) } ?? []
    }

    /// Prüft die PIN und legt das Gerät an. Danach gilt eine neue PIN.
    func pair(pin candidate: String, deviceName: String) -> Result<PairedDevice, PairingError> {
        let time = now()
        if let lockedUntil, time < lockedUntil { return .failure(.locked(until: lockedUntil)) }
        guard candidate == pin else {
            failedAttempts += 1
            if failedAttempts >= Self.maxFailedAttempts {
                failedAttempts = 0
                lockedUntil = time.addingTimeInterval(Self.lockDuration)
                pin = makePIN()
            }
            return .failure(.wrongPIN)
        }
        failedAttempts = 0
        lockedUntil = nil
        let name = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let device = PairedDevice(id: UUID(), name: name.isEmpty ? String(localized: "Gerät") : String(name.prefix(60)), token: Self.makeToken(), pairedAt: time)
        devices.append(device)
        save()
        pin = makePIN()
        return .success(device)
    }

    func device(forToken token: String) -> PairedDevice? {
        devices.first { $0.token == token }
    }

    func remove(_ id: PairedDevice.ID) {
        devices.removeAll { $0.id == id }
        save()
    }

    func renewPIN() {
        pin = makePIN()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(devices), forKey: Self.storageKey)
    }

    /// 32 Zufallsbytes als Hex.
    private static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }
}
