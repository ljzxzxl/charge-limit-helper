import Foundation

public enum ChargeLimitCommand: String, Codable, Sendable {
    case status
    case setBCLM
    case restoreDefault
}

public struct HelperRequest: Codable, Equatable, Sendable {
    public var command: ChargeLimitCommand
    public var value: UInt8?
    public var allowUnsupported: Bool

    public init(command: ChargeLimitCommand, value: UInt8? = nil, allowUnsupported: Bool = false) {
        self.command = command
        self.value = value
        self.allowUnsupported = allowUnsupported
    }
}

public struct HelperResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var message: String?
    public var error: String?
    public var bclm: UInt8?
    public var battery: BatterySnapshot?
    public var compatibility: CompatibilityReport?
    public var chargeState: ChargeState?

    public init(
        ok: Bool,
        message: String? = nil,
        error: String? = nil,
        bclm: UInt8? = nil,
        battery: BatterySnapshot? = nil,
        compatibility: CompatibilityReport? = nil,
        chargeState: ChargeState? = nil
    ) {
        self.ok = ok
        self.message = message
        self.error = error
        self.bclm = bclm
        self.battery = battery
        self.compatibility = compatibility
        self.chargeState = chargeState
    }
}

public enum ChargeLimitPaths {
    public static let socketPath = "/var/run/charge-limit-helper.sock"
    public static let helperLabel = "com.lookslikecode.ChargeLimitHelper"
    public static let monitorLabel = "com.lookslikecode.ChargeLimitMonitor"
    public static let helperInstallPath = "/Library/PrivilegedHelperTools/charge-limit-helperd"
    public static let logDirectory = "/Library/Logs/ChargeLimitHelper"
    public static let helperLogPath = "/Library/Logs/ChargeLimitHelper/helper.events.log"
    public static let monitorLogPath = "/tmp/charge-limit-monitor.log"
}

public enum JSONCodec {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
