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
      charge-limit doctor
      charge-limit self-test

    Commands:
      status          Query the installed helper daemon.
      pause           Write BCLM=15 via helper.
      resume          Write BCLM=100 via helper.
      set-bclm        Write an explicit BCLM value via helper.
      doctor          Read local battery/SMC state without using the helper.
      self-test       Run policy checks without touching hardware.
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
        batteryError: batteryError
    )
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

do {
    switch command {
    case "status":
        requireOK(try client.status())
    case "pause":
        requireOK(try client.setBCLM(15))
    case "resume":
        requireOK(try client.setBCLM(100))
    case "set-bclm":
        guard args.count == 2, let value = UInt8(args[1]) else {
            usage()
            exit(2)
        }
        requireOK(try client.setBCLM(value))
    case "doctor":
        printJSON(doctor())
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
