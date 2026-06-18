import Darwin
import Foundation
import IOKit

public struct CompatibilityReport: Codable, Equatable, Sendable {
    public var modelIdentifier: String?
    public var machineArchitecture: String
    public var isIntel: Bool
    public var isMacBook: Bool
    public var hasAppleSMC: Bool
    public var hasAppleSmartBattery: Bool
    public var canReadBCLM: Bool
    public var bclmValue: UInt8?
    public var errors: [String]

    public var isSupported: Bool {
        isIntel && isMacBook && hasAppleSMC && hasAppleSmartBattery && canReadBCLM
    }

    public var summary: String {
        if isSupported {
            return "supported Intel MacBook with readable BCLM"
        }
        return "unsupported or unverified: " + errors.joined(separator: "; ")
    }
}

public enum CompatibilityChecker {
    public static func report() -> CompatibilityReport {
        var errors = [String]()
        let model = sysctlString("hw.model")
        let architecture = machineArchitecture()
        let isIntel = architecture == "x86_64" || architecture == "i386"
        let isMacBook = model?.hasPrefix("MacBook") == true
        let hasSMC = serviceExists("AppleSMC")
        let hasBattery = serviceExists("AppleSmartBattery")

        if model == nil {
            errors.append("could not read hw.model")
        }
        if !isIntel {
            errors.append("machine architecture is \(architecture), not Intel")
        }
        if !isMacBook {
            errors.append("model is \(model ?? "unknown"), not a MacBook")
        }
        if !hasSMC {
            errors.append("AppleSMC service not found")
        }
        if !hasBattery {
            errors.append("AppleSmartBattery service not found")
        }

        var canReadBCLM = false
        var bclm: UInt8?
        if hasSMC {
            do {
                let smc = try SMC()
                bclm = try smc.readByte("BCLM")
                canReadBCLM = true
            } catch {
                errors.append("could not read BCLM: \(String(describing: error))")
            }
        }

        return CompatibilityReport(
            modelIdentifier: model,
            machineArchitecture: architecture,
            isIntel: isIntel,
            isMacBook: isMacBook,
            hasAppleSMC: hasSMC,
            hasAppleSmartBattery: hasBattery,
            canReadBCLM: canReadBCLM,
            bclmValue: bclm,
            errors: errors
        )
    }

    public static func unsafeOverrideEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let value = environment["CHARGE_LIMIT_UNSAFE_ALLOW_UNSUPPORTED"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }

    public static func requireSupported(allowUnsafeOverride: Bool = false) throws {
        let report = report()
        guard report.isSupported || allowUnsafeOverride || unsafeOverrideEnabled() else {
            throw CompatibilityError.unsupported(report)
        }
    }

    private static func serviceExists(_ serviceName: String) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        if service != 0 {
            IOObjectRelease(service)
            return true
        }
        return false
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }
        let end = buffer.firstIndex(of: 0) ?? buffer.count
        return String(decoding: buffer[..<end].map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    private static func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

public enum CompatibilityError: Error, CustomStringConvertible {
    case unsupported(CompatibilityReport)

    public var description: String {
        switch self {
        case .unsupported(let report):
            return report.summary
        }
    }
}
