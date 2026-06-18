import AppKit
import ChargeLimitCore
import Foundation

private enum DefaultsKey {
    static let targetPercent = "targetPercent"
    static let enabled = "enabled"
}

@MainActor
private final class MenuBarApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let service = SocketChargeLimitService()
    private var timer: Timer?
    private var lastResponse: HelperResponse?

    private var targetPercent: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: DefaultsKey.targetPercent)
            return stored == 0 ? 80 : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.targetPercent)
        }
    }

    private var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: DefaultsKey.enabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: DefaultsKey.enabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.enabled)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.button?.title = "CL"
        rebuildMenu(status: "Loading...")
        refreshStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    private func refreshStatus() {
        do {
            let response = try service.status()
            lastResponse = response
            if response.ok {
                let percent = response.battery?.uiStateOfCharge.map { "\($0)%" } ?? "--"
                let state = response.chargeState?.rawValue ?? "unknown"
                statusItem.button?.title = "\(percent) \(symbol(for: response.chargeState))"
                rebuildMenu(status: "\(percent) · \(state) · BCLM \(response.bclm.map(String.init) ?? "?")")
            } else {
                statusItem.button?.title = "CL !"
                rebuildMenu(status: response.error ?? "Helper error")
            }
        } catch {
            statusItem.button?.title = "CL !"
            rebuildMenu(status: "Helper unavailable")
        }
    }

    private func rebuildMenu(status: String) {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if let compatibility = lastResponse?.compatibility {
            let item = NSMenuItem(title: compatibility.isSupported ? "Supported: \(compatibility.modelIdentifier ?? "Mac")" : "Unsupported or unverified", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let enabled = NSMenuItem(title: "Enable Limit", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = isEnabled ? .on : .off
        enabled.target = self
        menu.addItem(enabled)

        let target = NSMenuItem(title: "Target: \(targetPercent)%", action: nil, keyEquivalent: "")
        let targetMenu = NSMenu()
        for value in [70, 75, 80, 82, 85, 90] {
            let item = NSMenuItem(title: "\(value)%", action: #selector(setTarget(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = value == targetPercent ? .on : .off
            item.target = self
            targetMenu.addItem(item)
        }
        target.submenu = targetMenu
        menu.addItem(target)

        let apply = NSMenuItem(title: "Apply Policy Now", action: #selector(applyPolicyNow), keyEquivalent: "")
        apply.target = self
        apply.isEnabled = isEnabled
        menu.addItem(apply)

        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause Charging", action: #selector(pauseCharging), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let resume = NSMenuItem(title: "Resume Charging", action: #selector(resumeCharging), keyEquivalent: "")
        resume.target = self
        menu.addItem(resume)

        let restore = NSMenuItem(title: "Restore Default", action: #selector(restoreDefault), keyEquivalent: "")
        restore.target = self
        menu.addItem(restore)

        menu.addItem(.separator())

        let install = NSMenuItem(title: "Install Helper (Dev)", action: #selector(installHelper), keyEquivalent: "")
        install.target = self
        menu.addItem(install)

        let uninstall = NSMenuItem(title: "Uninstall Helper (Dev)", action: #selector(uninstallHelper), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)

        let logs = NSMenuItem(title: "Show Logs", action: #selector(showLogs), keyEquivalent: "")
        logs.target = self
        menu.addItem(logs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        self.statusItem.menu = menu
    }

    private func symbol(for state: ChargeState?) -> String {
        switch state {
        case .charging:
            return "+"
        case .paused:
            return "="
        case .onBattery:
            return "-"
        case .full:
            return "100"
        case .unknown, nil:
            return "?"
        }
    }

    private func write(_ value: UInt8) {
        do {
            _ = try service.setBCLM(value, allowUnsupported: false)
            refreshStatus()
        } catch {
            showAlert(title: "Write Failed", message: String(describing: error))
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func runScript(_ relativePath: String, arguments: [String] = []) {
        let cwd = FileManager.default.currentDirectoryPath
        let script = "\(cwd)/\(relativePath)"
        guard FileManager.default.isExecutableFile(atPath: script) else {
            showAlert(title: "Script Not Found", message: "Could not find executable script at \(script). Run from the repository root for the development installer.")
            return
        }

        let quotedArguments = arguments.map { "'\($0.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: " ")
        let command = "\(script) \(quotedArguments)"
        let source = "do shell script \(String(reflecting: command)) with administrator privileges"
        var error: NSDictionary?
        if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
            showAlert(title: "Command Failed", message: error?.description ?? "Unknown AppleScript error")
        } else {
            refreshStatus()
        }
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        rebuildMenu(status: lastResponse?.chargeState?.rawValue ?? "Updated")
    }

    @objc private func setTarget(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Int {
            targetPercent = value
            rebuildMenu(status: lastResponse?.chargeState?.rawValue ?? "Updated")
        }
    }

    @objc private func applyPolicyNow() {
        guard isEnabled else {
            return
        }
        do {
            let response = try service.status()
            guard response.ok, let battery = response.battery else {
                showAlert(title: "Status Failed", message: response.error ?? "No battery data")
                return
            }
            let policy = try ChargeLimitPolicy(config: ChargeLimitConfig(targetPercent: targetPercent))
            let decision = try policy.decide(snapshot: battery, currentBCLM: response.bclm)
            if let value = decision.desiredSMCValue {
                _ = try service.setBCLM(value, allowUnsupported: false)
            }
            refreshStatus()
        } catch {
            showAlert(title: "Apply Failed", message: String(describing: error))
        }
    }

    @objc private func pauseCharging() {
        write(15)
    }

    @objc private func resumeCharging() {
        write(100)
    }

    @objc private func restoreDefault() {
        do {
            _ = try service.restoreDefault(allowUnsupported: false)
            refreshStatus()
        } catch {
            showAlert(title: "Restore Failed", message: String(describing: error))
        }
    }

    @objc private func installHelper() {
        runScript("scripts/install-helper.sh")
    }

    @objc private func uninstallHelper() {
        runScript("scripts/uninstall-helper.sh")
    }

    @objc private func showLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: ChargeLimitPaths.logDirectory))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private let app = NSApplication.shared
private let delegate = MenuBarApp()
app.delegate = delegate
app.run()
