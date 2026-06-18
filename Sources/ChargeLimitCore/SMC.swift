//
// SMC.swift
//
// Adapted from SMCKit.
//
// The MIT License
//
// Copyright (C) 2014-2017 beltex <https://beltex.github.io>
//

import Foundation
import IOKit

public typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

extension FourCharCode {
    init(smcKey: String) {
        precondition(smcKey.utf8.count == 4, "SMC keys must be exactly four bytes")
        self = smcKey.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    var smcString: String {
        String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
            String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
            String(describing: UnicodeScalar(self >> 8 & 0xff)!) +
            String(describing: UnicodeScalar(self & 0xff)!)
    }
}

public struct SMCDataType: Equatable, Sendable {
    let type: FourCharCode
    let size: UInt32

    static let uint8 = SMCDataType(type: FourCharCode(smcKey: "ui8 "), size: 1)
}

public struct SMCKey: Sendable {
    let code: FourCharCode
    let info: SMCDataType
}

public struct SMCParamStruct {
    enum Selector: UInt8 {
        case handleYPCEvent = 2
        case readKey = 5
        case writeKey = 6
        case getKeyInfo = 9
    }

    enum Result: UInt8 {
        case success = 0
        case error = 1
        case keyNotFound = 132
    }

    struct Version {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

public enum SMCError: Error, CustomStringConvertible {
    case driverNotFound
    case failedToOpen(kern_return_t)
    case keyNotFound(String)
    case notPrivileged
    case unknown(kernReturn: kern_return_t, smcResult: UInt8)

    public var description: String {
        switch self {
        case .driverNotFound:
            return "AppleSMC driver was not found"
        case .failedToOpen(let code):
            return "Failed to open AppleSMC: \(code)"
        case .keyNotFound(let key):
            return "SMC key not found: \(key)"
        case .notPrivileged:
            return "SMC write requires root privileges"
        case .unknown(let kernReturn, let smcResult):
            return "Unknown SMC error: kern=\(kernReturn) smc=\(smcResult)"
        }
    }
}

public final class SMC {
    private var connection: io_connect_t = 0

    public init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            throw SMCError.driverNotFound
        }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else {
            throw SMCError.failedToOpen(result)
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    public func readByte(_ key: String) throws -> UInt8 {
        let bytes = try readData(SMCKey(code: FourCharCode(smcKey: key), info: .uint8))
        return bytes.0
    }

    public func writeByte(_ key: String, value: UInt8) throws {
        try writeData(SMCKey(code: FourCharCode(smcKey: key), info: .uint8), bytes: bytes(first: value))
    }

    private func readData(_ key: SMCKey) throws -> SMCBytes {
        var input = SMCParamStruct()
        input.key = key.code
        input.keyInfo.dataSize = key.info.size
        input.data8 = SMCParamStruct.Selector.readKey.rawValue
        return try callDriver(&input).bytes
    }

    private func writeData(_ key: SMCKey, bytes: SMCBytes) throws {
        var input = SMCParamStruct()
        input.key = key.code
        input.bytes = bytes
        input.keyInfo.dataSize = key.info.size
        input.data8 = SMCParamStruct.Selector.writeKey.rawValue
        _ = try callDriver(&input)
    }

    private func callDriver(_ input: inout SMCParamStruct) throws -> SMCParamStruct {
        assert(MemoryLayout<SMCParamStruct>.stride == 80, "SMCParamStruct size must be 80 bytes")

        var output = SMCParamStruct()
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = IOConnectCallStructMethod(
            connection,
            UInt32(SMCParamStruct.Selector.handleYPCEvent.rawValue),
            &input,
            inputSize,
            &output,
            &outputSize
        )

        switch (result, output.result) {
        case (kIOReturnSuccess, SMCParamStruct.Result.success.rawValue):
            return output
        case (kIOReturnSuccess, SMCParamStruct.Result.keyNotFound.rawValue):
            throw SMCError.keyNotFound(input.key.smcString)
        case (kIOReturnNotPrivileged, _):
            throw SMCError.notPrivileged
        default:
            throw SMCError.unknown(kernReturn: result, smcResult: output.result)
        }
    }

    private func bytes(first value: UInt8) -> SMCBytes {
        (value, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }
}
