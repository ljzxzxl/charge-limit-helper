import ChargeLimitCore
import Foundation

private struct Options {
    var target = 80
    var hysteresis = 2
    var interval: UInt64 = 30
    var once = false
    var verbose = false
}

private func usage() {
    print("""
    charge-limit-monitor

    Usage:
      charge-limit-monitor --target <50-100> [--hysteresis <1-20>] [--interval <seconds>] [--once] [--verbose]

    The monitor talks to charge-limit-helperd over its local Unix socket.
    It writes BCLM=100 below the resume threshold and BCLM=15 at or above target.
    """)
}

private func parseOptions() -> Options {
    var options = Options()
    var index = 1
    let args = CommandLine.arguments

    while index < args.count {
        switch args[index] {
        case "--target":
            index += 1
            guard index < args.count, let value = Int(args[index]) else {
                usage()
                exit(2)
            }
            options.target = value
        case "--hysteresis":
            index += 1
            guard index < args.count, let value = Int(args[index]) else {
                usage()
                exit(2)
            }
            options.hysteresis = value
        case "--interval":
            index += 1
            guard index < args.count, let value = UInt64(args[index]) else {
                usage()
                exit(2)
            }
            options.interval = value
        case "--once":
            options.once = true
        case "--verbose":
            options.verbose = true
        case "--help", "-h":
            usage()
            exit(0)
        default:
            usage()
            exit(2)
        }
        index += 1
    }

    return options
}

private func log(_ message: String) {
    let formatter = ISO8601DateFormatter()
    print("\(formatter.string(from: Date())) \(message)")
    fflush(stdout)
}

private func runOnce(client: HelperClient, policy: ChargeLimitPolicy, verbose: Bool) {
    do {
        let status = try client.status()
        guard status.ok else {
            log("helper error: \(status.error ?? "unknown error")")
            return
        }
        guard let battery = status.battery else {
            log("helper did not return battery data")
            return
        }

        let decision = try policy.decide(snapshot: battery, currentBCLM: status.bclm)
        if verbose {
            log("ui=\(battery.uiStateOfCharge.map(String.init) ?? "?") bclm=\(status.bclm.map(String.init) ?? "?") decision=\(decision.reason)")
        }

        guard let desired = decision.desiredSMCValue else {
            return
        }

        let write = try client.setBCLM(desired)
        if write.ok {
            log("wrote BCLM=\(write.bclm ?? desired): \(decision.reason)")
        } else {
            log("write failed: \(write.error ?? "unknown error")")
        }
    } catch {
        log("monitor error: \(String(describing: error))")
    }
}

private let options = parseOptions()

do {
    let config = try ChargeLimitConfig(
        targetPercent: options.target,
        hysteresisPercent: options.hysteresis,
        pollIntervalSeconds: options.interval
    ).validated()
    let policy = try ChargeLimitPolicy(config: config)
    let client = HelperClient()

    log("monitor started target=\(config.targetPercent)% resume<=\(config.targetPercent - config.hysteresisPercent)% interval=\(config.pollIntervalSeconds)s")
    repeat {
        runOnce(client: client, policy: policy, verbose: options.verbose)
        if options.once {
            break
        }
        sleep(UInt32(config.pollIntervalSeconds))
    } while true
} catch {
    fputs("charge-limit-monitor: \(String(describing: error))\n", stderr)
    exit(1)
}
