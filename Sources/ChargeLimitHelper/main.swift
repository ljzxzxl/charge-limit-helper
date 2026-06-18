import ChargeLimitCore
import Darwin
import Foundation

private let version = "0.1-dev"
private let defaultBCLMValue: UInt8 = 100
private let minimumWriteInterval: TimeInterval = 2

private final class HelperState: @unchecked Sendable {
    private let lock = NSLock()
    private var lastWriteDate: Date?
    private var lastWrittenValue: UInt8?

    func isRateLimited(now: Date = Date(), minimumInterval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let lastWriteDate else {
            return false
        }
        return now.timeIntervalSince(lastWriteDate) < minimumInterval
    }

    func recordWrite(_ value: UInt8, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        lastWriteDate = now
        lastWrittenValue = value
    }
}

private let helperState = HelperState()

private func usage() {
    print("""
    charge-limit-helperd \(version)

    Usage:
      charge-limit-helperd --daemon
      charge-limit-helperd status
      charge-limit-helperd set-bclm [--unsafe-allow-unsupported] <value>
      charge-limit-helperd restore-default [--unsafe-allow-unsupported]

    The daemon mode is intended to run as root via launchd.
    """)
}

private func logEvent(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    fputs(line, stderr)

    do {
        try FileManager.default.createDirectory(
            atPath: ChargeLimitPaths.logDirectory,
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: ChargeLimitPaths.helperLogPath) {
            FileManager.default.createFile(atPath: ChargeLimitPaths.helperLogPath, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: ChargeLimitPaths.helperLogPath))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
    } catch {
        // stderr still receives the event; file logging should not break helper work.
    }
}

private func statusResponse(message: String? = nil) -> HelperResponse {
    do {
        let smc = try SMC()
        let bclm = try smc.readByte("BCLM")
        let battery = try? BatteryReader.snapshot()
        let compatibility = CompatibilityChecker.report()
        return HelperResponse(
            ok: true,
            message: message,
            bclm: bclm,
            battery: battery,
            compatibility: compatibility,
            chargeState: ChargeStateResolver.resolve(battery: battery, bclm: bclm)
        )
    } catch {
        return HelperResponse(ok: false, error: String(describing: error))
    }
}

private func setBCLMResponse(_ value: UInt8, allowUnsupported: Bool = false, reason: String = "explicit request") -> HelperResponse {
    do {
        try CompatibilityChecker.requireSupported(allowUnsafeOverride: allowUnsupported)

        let smc = try SMC()
        let current = try smc.readByte("BCLM")
        if current == value {
            let battery = try? BatteryReader.snapshot()
            return HelperResponse(
                ok: true,
                message: "BCLM already \(value)",
                bclm: current,
                battery: battery,
                compatibility: CompatibilityChecker.report(),
                chargeState: ChargeStateResolver.resolve(battery: battery, bclm: current)
            )
        }

        if helperState.isRateLimited(minimumInterval: minimumWriteInterval) {
            return HelperResponse(
                ok: false,
                error: "SMC write rate-limited; wait at least \(Int(minimumWriteInterval)) seconds between different values",
                bclm: current,
                battery: try? BatteryReader.snapshot(),
                compatibility: CompatibilityChecker.report()
            )
        }

        try smc.writeByte("BCLM", value: value)
        let actual = try? smc.readByte("BCLM")
        let battery = try? BatteryReader.snapshot()
        helperState.recordWrite(actual ?? value)
        logEvent("set BCLM=\(actual ?? value) reason=\"\(reason)\" allowUnsupported=\(allowUnsupported)")

        return HelperResponse(
            ok: true,
            message: "BCLM set to \(actual ?? value)",
            bclm: actual,
            battery: battery,
            compatibility: CompatibilityChecker.report(),
            chargeState: ChargeStateResolver.resolve(battery: battery, bclm: actual ?? value)
        )
    } catch {
        logEvent("failed to set BCLM=\(value): \(String(describing: error))")
        return HelperResponse(ok: false, error: String(describing: error))
    }
}

private func handle(_ request: HelperRequest) -> HelperResponse {
    switch request.command {
    case .status:
        return statusResponse(message: "helper \(version), euid=\(geteuid())")
    case .setBCLM:
        guard let value = request.value else {
            return HelperResponse(ok: false, error: "setBCLM requires a value")
        }
        guard (1...100).contains(value) else {
            return HelperResponse(ok: false, error: "BCLM value must be between 1 and 100")
        }
        return setBCLMResponse(value, allowUnsupported: request.allowUnsupported)
    case .restoreDefault:
        return setBCLMResponse(defaultBCLMValue, allowUnsupported: request.allowUnsupported, reason: "restore default")
    }
}

private func writeResponse(_ response: HelperResponse, to fd: Int32) {
    do {
        var data = try JSONCodec.encoder.encode(response)
        data.append(0x0a)
        try UnixSocket.writeAll(fd: fd, data: data)
    } catch {
        let fallback = "{\"ok\":false,\"error\":\"\(String(describing: error))\"}\n"
        _ = fallback.withCString { Darwin.write(fd, $0, strlen($0)) }
    }
}

private func serve() throws -> Never {
    guard geteuid() == 0 else {
        fputs("charge-limit-helperd --daemon must run as root\n", stderr)
        exit(77)
    }

    let server = try UnixSocket.openServer(path: ChargeLimitPaths.socketPath)
    logEvent("charge-limit-helperd \(version) listening on \(ChargeLimitPaths.socketPath)")
    print("charge-limit-helperd \(version) listening on \(ChargeLimitPaths.socketPath)")
    fflush(stdout)

    while true {
        let client = try UnixSocket.acceptClient(serverFD: server)
        autoreleasepool {
            defer { close(client) }
            do {
                let requestData = try UnixSocket.readUntilEOF(fd: client)
                let request = try JSONCodec.decoder.decode(HelperRequest.self, from: requestData)
                writeResponse(handle(request), to: client)
            } catch {
                writeResponse(HelperResponse(ok: false, error: String(describing: error)), to: client)
            }
        }
    }
}

private func printJSON(_ response: HelperResponse) {
    do {
        let data = try JSONCodec.encoder.encode(response)
        FileHandle.standardOutput.write(data)
        print()
    } catch {
        print(response)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty {
    usage()
    exit(2)
}

switch arguments[0] {
case "--daemon":
    do {
        try serve()
    } catch {
        fputs("daemon failed: \(String(describing: error))\n", stderr)
        exit(1)
    }
case "status":
    printJSON(statusResponse())
case "set-bclm":
    let allowUnsupported = arguments.contains("--unsafe-allow-unsupported")
    let valueArgument = arguments.dropFirst().first { !$0.hasPrefix("--") }
    guard let valueArgument, let value = UInt8(valueArgument) else {
        usage()
        exit(2)
    }
    printJSON(setBCLMResponse(value, allowUnsupported: allowUnsupported))
case "restore-default":
    let allowUnsupported = arguments.contains("--unsafe-allow-unsupported")
    printJSON(setBCLMResponse(defaultBCLMValue, allowUnsupported: allowUnsupported, reason: "restore default"))
default:
    usage()
    exit(2)
}
