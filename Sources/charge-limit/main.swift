import ChargeLimitCore
import Foundation

private func usage() {
    print("""
    charge-limit

    Usage:
      charge-limit status
      charge-limit pause
      charge-limit resume
      charge-limit set-bclm <value>
      charge-limit restore-default
      charge-limit doctor
      charge-limit logs
      charge-limit self-test

    Commands:
      status          Query the installed helper daemon.
      pause           Write BCLM=15 via helper.
      resume          Write BCLM=100 via helper.
      set-bclm        Write an explicit BCLM value via helper.
      restore-default Write BCLM=100 via helper.
      doctor          Read local battery/SMC state without using the helper.
      logs            Print known helper and monitor logs.
      self-test       Run policy checks without touching hardware.

    Options:
      --unsafe-allow-unsupported
                      Allow writes on unsupported or unverified machines.
                      Intended for development only.
    """)
}

private func printJSON<T: Encodable>(_ value: T) {
    do {
        let data = try JSONCodec.encoder.encode(value)
        FileHandle.standardOutput.write(data)
        print()
    } catch {
        print(value)
    }
}

private func requireOK(_ response: HelperResponse) {
    printJSON(response)
    if !response.ok {
        exit(1)
    }
}

private struct DoctorReport: Codable {
    var helperSocketPath: String
    var localBCLM: UInt8?
    var localBCLMError: String?
    var battery: BatterySnapshot?
    var batteryError: String?
    var compatibility: CompatibilityReport
    var chargeState: ChargeState
}

private func doctor() -> DoctorReport {
    var bclm: UInt8?
    var smcError: String?
    do {
        let smc = try SMC()
        bclm = try smc.readByte("BCLM")
    } catch {
        smcError = String(describing: error)
    }

    var battery: BatterySnapshot?
    var batteryError: String?
    do {
        battery = try BatteryReader.snapshot()
    } catch {
        batteryError = String(describing: error)
    }

    return DoctorReport(
        helperSocketPath: ChargeLimitPaths.socketPath,
        localBCLM: bclm,
        localBCLMError: smcError,
        battery: battery,
        batteryError: batteryError,
        compatibility: CompatibilityChecker.report(),
        chargeState: ChargeStateResolver.resolve(battery: battery, bclm: bclm)
    )
}

private func printLogs() {
    let paths = [
        ChargeLimitPaths.helperLogPath,
        "\(ChargeLimitPaths.logDirectory)/helper.log",
        "\(ChargeLimitPaths.logDirectory)/helper.err.log",
        ChargeLimitPaths.monitorLogPath,
        "/tmp/charge-limiter-monitor.err.log"
    ]

    for path in paths {
        print("==> \(path)")
        guard FileManager.default.fileExists(atPath: path) else {
            print("(missing)")
            continue
        }
        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let tail = lines.suffix(80)
            for line in tail {
                print(line)
            }
        } catch {
            print("could not read: \(String(describing: error))")
        }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("self-test failed: \(message)\n", stderr)
        exit(1)
    }
}

private func selfTest() throws {
    let policy = try ChargeLimitPolicy(config: ChargeLimitConfig(targetPercent: 82, hysteresisPercent: 2))

    let pause = try policy.decide(snapshot: BatterySnapshot(uiStateOfCharge: 82), currentBCLM: 100)
    expect(pause.desiredSMCValue == 15, "should pause at target")

    let resume = try policy.decide(snapshot: BatterySnapshot(uiStateOfCharge: 80), currentBCLM: 15)
    expect(resume.desiredSMCValue == 100, "should resume at lower hysteresis threshold")

    let hold = try policy.decide(snapshot: BatterySnapshot(uiStateOfCharge: 81), currentBCLM: 15)
    expect(hold.desiredSMCValue == nil, "should hold inside hysteresis window")

    do {
        _ = try ChargeLimitConfig(targetPercent: 40).validated()
        expect(false, "should reject invalid target")
    } catch {
        // Expected.
    }

    print("self-test ok")
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    usage()
    exit(2)
}

let client = HelperClient()
let allowUnsupported = args.contains("--unsafe-allow-unsupported")

do {
    switch command {
    case "status":
        requireOK(try client.status())
    case "pause":
        requireOK(try client.setBCLM(15, allowUnsupported: allowUnsupported))
    case "resume":
        requireOK(try client.setBCLM(100, allowUnsupported: allowUnsupported))
    case "set-bclm":
        guard let valueArgument = args.dropFirst().first(where: { !$0.hasPrefix("--") }),
              let value = UInt8(valueArgument) else {
            usage()
            exit(2)
        }
        requireOK(try client.setBCLM(value, allowUnsupported: allowUnsupported))
    case "restore-default":
        requireOK(try client.restoreDefault(allowUnsupported: allowUnsupported))
    case "doctor":
        printJSON(doctor())
    case "logs":
        printLogs()
    case "self-test":
        try selfTest()
    default:
        usage()
        exit(2)
    }
} catch {
    fputs("charge-limit: \(String(describing: error))\n", stderr)
    exit(1)
}
