import Foundation
import IOKit

public struct BatterySnapshot: Codable, Equatable {
    public var uiStateOfCharge: Int?
    public var rawStateOfCharge: Int?
    public var currentCapacity: Int?
    public var maxCapacity: Int?
    public var isCharging: Bool?
    public var externalConnected: Bool?
    public var fullyCharged: Bool?
    public var chargingCurrent: Int?
    public var notChargingReason: Int?
    public var amperage: Int?
    public var instantAmperage: Int?
    public var voltage: Int?
    public var timeRemaining: Int?
    public var timestamp: Date

    public init(
        uiStateOfCharge: Int? = nil,
        rawStateOfCharge: Int? = nil,
        currentCapacity: Int? = nil,
        maxCapacity: Int? = nil,
        isCharging: Bool? = nil,
        externalConnected: Bool? = nil,
        fullyCharged: Bool? = nil,
        chargingCurrent: Int? = nil,
        notChargingReason: Int? = nil,
        amperage: Int? = nil,
        instantAmperage: Int? = nil,
        voltage: Int? = nil,
        timeRemaining: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.uiStateOfCharge = uiStateOfCharge
        self.rawStateOfCharge = rawStateOfCharge
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.isCharging = isCharging
        self.externalConnected = externalConnected
        self.fullyCharged = fullyCharged
        self.chargingCurrent = chargingCurrent
        self.notChargingReason = notChargingReason
        self.amperage = amperage
        self.instantAmperage = instantAmperage
        self.voltage = voltage
        self.timeRemaining = timeRemaining
        self.timestamp = timestamp
    }
}

public enum BatteryReaderError: Error, CustomStringConvertible {
    case serviceNotFound
    case failedToReadProperties(kern_return_t)

    public var description: String {
        switch self {
        case .serviceNotFound:
            return "AppleSmartBattery service was not found"
        case .failedToReadProperties(let code):
            return "Failed to read AppleSmartBattery properties: \(code)"
        }
    }
}

public enum BatteryReader {
    public static func snapshot() throws -> BatterySnapshot {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            throw BatteryReaderError.serviceNotFound
        }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == kIOReturnSuccess, let retained = properties?.takeRetainedValue() else {
            throw BatteryReaderError.failedToReadProperties(result)
        }

        let dictionary = retained as NSDictionary
        let batteryData = dictionary["BatteryData"] as? NSDictionary
        let chargerData = dictionary["ChargerData"] as? NSDictionary

        return BatterySnapshot(
            uiStateOfCharge: int("UISoc", in: batteryData),
            rawStateOfCharge: int("StateOfCharge", in: batteryData),
            currentCapacity: int("CurrentCapacity", in: dictionary),
            maxCapacity: int("MaxCapacity", in: dictionary),
            isCharging: bool("IsCharging", in: dictionary),
            externalConnected: bool("ExternalConnected", in: dictionary),
            fullyCharged: bool("FullyCharged", in: dictionary),
            chargingCurrent: int("ChargingCurrent", in: chargerData),
            notChargingReason: int("NotChargingReason", in: chargerData),
            amperage: int("Amperage", in: dictionary),
            instantAmperage: int("InstantAmperage", in: dictionary),
            voltage: int("Voltage", in: dictionary),
            timeRemaining: int("TimeRemaining", in: dictionary)
        )
    }

    private static func int(_ key: String, in dictionary: NSDictionary?) -> Int? {
        guard let value = dictionary?[key] else {
            return nil
        }
        if let number = value as? NSNumber {
            return Int(number.int64Value)
        }
        if let integer = value as? Int {
            return integer
        }
        return nil
    }

    private static func bool(_ key: String, in dictionary: NSDictionary?) -> Bool? {
        guard let value = dictionary?[key] else {
            return nil
        }
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}
