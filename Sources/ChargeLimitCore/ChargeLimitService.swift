import Foundation

public protocol ChargeLimitServicing {
    func status() throws -> HelperResponse
    func setBCLM(_ value: UInt8, allowUnsupported: Bool) throws -> HelperResponse
    func restoreDefault(allowUnsupported: Bool) throws -> HelperResponse
}

public struct SocketChargeLimitService: ChargeLimitServicing {
    public var client: HelperClient

    public init(client: HelperClient = HelperClient()) {
        self.client = client
    }

    public func status() throws -> HelperResponse {
        try client.status()
    }

    public func setBCLM(_ value: UInt8, allowUnsupported: Bool = false) throws -> HelperResponse {
        try client.setBCLM(value, allowUnsupported: allowUnsupported)
    }

    public func restoreDefault(allowUnsupported: Bool = false) throws -> HelperResponse {
        try client.restoreDefault(allowUnsupported: allowUnsupported)
    }
}

public enum ChargeState: String, Codable, Equatable, Sendable {
    case charging
    case paused
    case onBattery
    case full
    case unknown
}

public enum ChargeStateResolver {
    public static func resolve(battery: BatterySnapshot?, bclm: UInt8?) -> ChargeState {
        guard let battery else {
            return .unknown
        }
        if battery.externalConnected == false {
            return .onBattery
        }
        if battery.fullyCharged == true {
            return .full
        }
        if battery.isCharging == true {
            return .charging
        }
        if bclm == 15 {
            return .paused
        }
        if battery.chargingCurrent == 0 && battery.notChargingReason == 14 {
            return .paused
        }
        if battery.isCharging == nil,
           (battery.amperage ?? battery.instantAmperage ?? 0) > 0 {
            return .charging
        }
        return .unknown
    }
}
