import Foundation

public enum ChargeLimitCommand: String, Codable {
    case status
    case setBCLM
}

public struct HelperRequest: Codable, Equatable {
    public var command: ChargeLimitCommand
    public var value: UInt8?

    public init(command: ChargeLimitCommand, value: UInt8? = nil) {
        self.command = command
        self.value = value
    }
}

public struct HelperResponse: Codable, Equatable {
    public var ok: Bool
    public var message: String?
    public var error: String?
    public var bclm: UInt8?
    public var battery: BatterySnapshot?

    public init(
        ok: Bool,
        message: String? = nil,
        error: String? = nil,
        bclm: UInt8? = nil,
        battery: BatterySnapshot? = nil
    ) {
        self.ok = ok
        self.message = message
        self.error = error
        self.bclm = bclm
        self.battery = battery
    }
}

public enum ChargeLimitPaths {
    public static let socketPath = "/var/run/charge-limit-helper.sock"
    public static let helperLabel = "com.lookslikecode.ChargeLimitHelper"
    public static let helperInstallPath = "/Library/PrivilegedHelperTools/charge-limit-helperd"
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
