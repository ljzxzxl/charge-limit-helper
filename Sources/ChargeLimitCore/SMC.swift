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

public struct SMCRawValue: Codable, Equatable, Sendable {
    public var key: String
    public var dataSize: UInt32
    public var dataType: String
    public var attributes: UInt8
    public var bytes: [UInt8]
    public var hex: String
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
    case invalidDataSize(expected: UInt32, actual: Int)
    case invalidHex(String)
    case keyNotFound(String)
    case notPrivileged
    case unknown(kernReturn: kern_return_t, smcResult: UInt8)

    public var description: String {
        switch self {
        case .driverNotFound:
            return "AppleSMC driver was not found"
        case .failedToOpen(let code):
            return "Failed to open AppleSMC: \(code)"
        case .invalidDataSize(let expected, let actual):
            return "Invalid SMC data size: expected \(expected) bytes, got \(actual)"
        case .invalidHex(let value):
            return "Invalid hex value: \(value)"
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

    public func readRaw(_ key: String) throws -> SMCRawValue {
        let keyCode = FourCharCode(smcKey: key)
        let keyInfo = try getKeyInfo(keyCode)
        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo = keyInfo
        input.data8 = SMCParamStruct.Selector.readKey.rawValue
        let output = try callDriver(&input)
        let dataSize = min(Int(keyInfo.dataSize), 32)
        let bytes = Array(byteArray(output.bytes).prefix(dataSize))
        return SMCRawValue(
            key: key,
            dataSize: keyInfo.dataSize,
            dataType: keyInfo.dataType.smcString,
            attributes: keyInfo.dataAttributes,
            bytes: bytes,
            hex: bytes.map { String(format: "%02x", $0) }.joined()
        )
    }

    public func writeRawHex(_ key: String, hex: String) throws -> SMCRawValue {
        let keyCode = FourCharCode(smcKey: key)
        let keyInfo = try getKeyInfo(keyCode)
        let bytes = try parseHex(hex)
        guard bytes.count == Int(keyInfo.dataSize) else {
            throw SMCError.invalidDataSize(expected: keyInfo.dataSize, actual: bytes.count)
        }

        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo = keyInfo
        input.bytes = tuple(bytes)
        input.data8 = SMCParamStruct.Selector.writeKey.rawValue
        _ = try callDriver(&input)
        if let raw = try? readRaw(key) {
            return raw
        }
        return SMCRawValue(
            key: key,
            dataSize: keyInfo.dataSize,
            dataType: keyInfo.dataType.smcString,
            attributes: keyInfo.dataAttributes,
            bytes: bytes,
            hex: bytes.map { String(format: "%02x", $0) }.joined()
        )
    }

    private func readData(_ key: SMCKey) throws -> SMCBytes {
        var input = SMCParamStruct()
        input.key = key.code
        input.keyInfo.dataSize = key.info.size
        input.data8 = SMCParamStruct.Selector.readKey.rawValue
        return try callDriver(&input).bytes
    }

    private func getKeyInfo(_ key: FourCharCode) throws -> SMCParamStruct.KeyInfoData {
        var input = SMCParamStruct()
        input.key = key
        input.data8 = SMCParamStruct.Selector.getKeyInfo.rawValue
        return try callDriver(&input).keyInfo
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

    private func byteArray(_ bytes: SMCBytes) -> [UInt8] {
        [
            bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15,
            bytes.16, bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23,
            bytes.24, bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31
        ]
    }

    private func tuple(_ bytes: [UInt8]) -> SMCBytes {
        let padded = bytes + Array(repeating: UInt8(0), count: max(0, 32 - bytes.count))
        return (
            padded[0], padded[1], padded[2], padded[3], padded[4], padded[5], padded[6], padded[7],
            padded[8], padded[9], padded[10], padded[11], padded[12], padded[13], padded[14], padded[15],
            padded[16], padded[17], padded[18], padded[19], padded[20], padded[21], padded[22], padded[23],
            padded[24], padded[25], padded[26], padded[27], padded[28], padded[29], padded[30], padded[31]
        )
    }

    private func parseHex(_ hex: String) throws -> [UInt8] {
        let normalized = hex
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        guard normalized.count.isMultiple(of: 2) else {
            throw SMCError.invalidHex(hex)
        }

        var bytes: [UInt8] = []
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<next], radix: 16) else {
                throw SMCError.invalidHex(hex)
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }
}
