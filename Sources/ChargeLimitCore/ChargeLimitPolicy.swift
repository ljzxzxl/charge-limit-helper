import Foundation

public struct ChargeLimitConfig: Codable, Equatable {
    public var enabled: Bool
    public var targetPercent: Int
    public var hysteresisPercent: Int
    public var pauseSMCValue: UInt8
    public var chargeSMCValue: UInt8
    public var pollIntervalSeconds: UInt64
    public var resumeAtTargetPercent: Bool
    public var rawDischargeSafetyMarginPercent: Int

    public init(
        enabled: Bool = true,
        targetPercent: Int = 80,
        hysteresisPercent: Int = 2,
        pauseSMCValue: UInt8 = 15,
        chargeSMCValue: UInt8 = 100,
        pollIntervalSeconds: UInt64 = 30,
        resumeAtTargetPercent: Bool = false,
        rawDischargeSafetyMarginPercent: Int = 4
    ) {
        self.enabled = enabled
        self.targetPercent = targetPercent
        self.hysteresisPercent = hysteresisPercent
        self.pauseSMCValue = pauseSMCValue
        self.chargeSMCValue = chargeSMCValue
        self.pollIntervalSeconds = pollIntervalSeconds
        self.resumeAtTargetPercent = resumeAtTargetPercent
        self.rawDischargeSafetyMarginPercent = rawDischargeSafetyMarginPercent
    }

    public func validated() throws -> ChargeLimitConfig {
        guard (50...100).contains(targetPercent) else {
            throw ChargeLimitPolicyError.invalidTarget(targetPercent)
        }
        guard (1...20).contains(hysteresisPercent) else {
            throw ChargeLimitPolicyError.invalidHysteresis(hysteresisPercent)
        }
        guard (0...20).contains(rawDischargeSafetyMarginPercent) else {
            throw ChargeLimitPolicyError.invalidRawDischargeSafetyMargin(rawDischargeSafetyMarginPercent)
        }
        guard pauseSMCValue < chargeSMCValue else {
            throw ChargeLimitPolicyError.invalidSMCValues
        }
        return self
    }
}

public enum ChargeLimitPolicyError: Error, CustomStringConvertible {
    case invalidTarget(Int)
    case invalidHysteresis(Int)
    case invalidRawDischargeSafetyMargin(Int)
    case invalidSMCValues
    case missingBatteryPercent

    public var description: String {
        switch self {
        case .invalidTarget(let value):
            return "Target percent must be between 50 and 100, got \(value)"
        case .invalidHysteresis(let value):
            return "Hysteresis percent must be between 1 and 20, got \(value)"
        case .invalidRawDischargeSafetyMargin(let value):
            return "Raw discharge safety margin must be between 0 and 20, got \(value)"
        case .invalidSMCValues:
            return "Pause SMC value must be lower than charge SMC value"
        case .missingBatteryPercent:
            return "Battery UI percentage is unavailable"
        }
    }
}

public enum ChargeLimitDecision: Codable, Equatable {
    case write(UInt8, reason: String)
    case hold(reason: String)
    case disabled(reason: String)

    public var desiredSMCValue: UInt8? {
        if case .write(let value, _) = self {
            return value
        }
        return nil
    }

    public var reason: String {
        switch self {
        case .write(_, let reason), .hold(let reason), .disabled(let reason):
            return reason
        }
    }
}

public struct ChargeLimitPolicy {
    public let config: ChargeLimitConfig

    public init(config: ChargeLimitConfig) throws {
        self.config = try config.validated()
    }

    public func decide(snapshot: BatterySnapshot, currentBCLM: UInt8?) throws -> ChargeLimitDecision {
        guard config.enabled else {
            return .disabled(reason: "charge limiting disabled")
        }

        guard let percent = snapshot.uiStateOfCharge else {
            throw ChargeLimitPolicyError.missingBatteryPercent
        }

        if config.resumeAtTargetPercent {
            if let rawPercent = snapshot.rawStateOfCharge {
                let rawSafetyPercent = max(0, config.targetPercent - config.rawDischargeSafetyMarginPercent)
                if rawPercent <= rawSafetyPercent {
                    if currentBCLM == config.chargeSMCValue {
                        return .hold(reason: "already allowing charge at raw safety floor \(rawSafetyPercent)%")
                    }
                    return .write(config.chargeSMCValue, reason: "raw battery reached safety floor \(rawSafetyPercent)%")
                }
            }

            if percent > config.targetPercent {
                if currentBCLM == config.pauseSMCValue {
                    return .hold(reason: "already discharging above visible target")
                }
                return .write(config.pauseSMCValue, reason: "visible battery is above target \(config.targetPercent)%")
            }
        }

        if percent >= config.targetPercent {
            if currentBCLM == config.pauseSMCValue {
                return .hold(reason: "already paused at or above target")
            }
            return .write(config.pauseSMCValue, reason: "battery reached target \(config.targetPercent)%")
        }

        let resumePercent = max(0, config.targetPercent - config.hysteresisPercent)
        if percent <= resumePercent {
            if currentBCLM == config.chargeSMCValue {
                return .hold(reason: "already allowing charge below resume threshold")
            }
            return .write(config.chargeSMCValue, reason: "battery is below resume threshold \(resumePercent)%")
        }

        return .hold(reason: "battery is inside hysteresis window")
    }
}
