import ChargeLimitCore
import Darwin
import Foundation

private let version = "0.1-dev"

private func usage() {
    print("""
    charge-limit-helperd \(version)

    Usage:
      charge-limit-helperd --daemon
      charge-limit-helperd status
      charge-limit-helperd set-bclm <value>

    The daemon mode is intended to run as root via launchd.
    """)
}

private func statusResponse(message: String? = nil) -> HelperResponse {
    do {
        let smc = try SMC()
        let bclm = try smc.readByte("BCLM")
        let battery = try? BatteryReader.snapshot()
        return HelperResponse(ok: true, message: message, bclm: bclm, battery: battery)
    } catch {
        return HelperResponse(ok: false, error: String(describing: error))
    }
}

private func setBCLMResponse(_ value: UInt8) -> HelperResponse {
    do {
        let smc = try SMC()
        try smc.writeByte("BCLM", value: value)
        let actual = try? smc.readByte("BCLM")
        let battery = try? BatteryReader.snapshot()
        return HelperResponse(
            ok: true,
            message: "BCLM set to \(actual ?? value)",
            bclm: actual,
            battery: battery
        )
    } catch {
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
        return setBCLMResponse(value)
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
    guard arguments.count == 2, let value = UInt8(arguments[1]) else {
        usage()
        exit(2)
    }
    printJSON(setBCLMResponse(value))
default:
    usage()
    exit(2)
}
