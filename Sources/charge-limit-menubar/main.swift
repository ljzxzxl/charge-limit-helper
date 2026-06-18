import AppKit
import ChargeLimitCore
import Foundation
import ServiceManagement

private enum DefaultsKey {
    static let targetPercent = "targetPercent"
    static let enabled = "enabled"
    static let didShowFirstRunGuidance = "didShowFirstRunGuidance"
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
        configureStatusItem(title: "")
        rebuildMenu(status: "Loading...")
        refreshStatus()
        Task { @MainActor in
            showFirstRunGuidanceIfNeeded()
        }
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
                applyPolicyIfNeeded(response: response)
                let percent = response.battery?.uiStateOfCharge.map { "\($0)%" } ?? "--"
                let state = response.chargeState?.rawValue ?? "unknown"
                configureStatusItem(title: "\(percent) \(symbol(for: response.chargeState))")
                rebuildMenu(status: "\(percent) · \(state) · BCLM \(response.bclm.map(String.init) ?? "?")")
            } else {
                configureStatusItem(title: "!")
                rebuildMenu(status: response.error ?? "Helper error")
            }
        } catch {
            configureStatusItem(title: "!")
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

        let launchAtLogin = NSMenuItem(title: launchAtLoginTitle(), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.state = launchAtLoginState()
        launchAtLogin.target = self
        menu.addItem(launchAtLogin)

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

        let install = NSMenuItem(title: "Install Helper", action: #selector(installHelper), keyEquivalent: "")
        install.target = self
        menu.addItem(install)

        let uninstall = NSMenuItem(title: "Uninstall Helper", action: #selector(uninstallHelper), keyEquivalent: "")
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

    private func configureStatusItem(title: String) {
        guard let button = statusItem.button else {
            return
        }

        button.image = menuBarImage()
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeft
        button.title = title
    }

    private func menuBarImage() -> NSImage? {
        let resourceName = usesDarkAppearance ? "MenuBarIconDark" : "MenuBarIconLight"
        let image = loadImage(named: resourceName)
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }

    private var usesDarkAppearance: Bool {
        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func loadImage(named name: String) -> NSImage? {
        if let bundled = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: bundled) {
            return image
        }

        let repoPath = "\(FileManager.default.currentDirectoryPath)/Resources/\(name).png"
        return NSImage(contentsOfFile: repoPath)
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

    private func applyPolicyIfNeeded(response: HelperResponse) {
        guard isEnabled, let battery = response.battery else {
            return
        }

        do {
            let policy = try ChargeLimitPolicy(config: ChargeLimitConfig(targetPercent: targetPercent))
            let decision = try policy.decide(snapshot: battery, currentBCLM: response.bclm)
            if let value = decision.desiredSMCValue {
                _ = try service.setBCLM(value, allowUnsupported: false)
            }
        } catch {
            // The menu remains usable; the next refresh or manual action can surface errors.
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func runScript(named scriptName: String, arguments: [String] = [], completion: ((Bool) -> Void)? = nil) {
        let bundledScript = Bundle.main.resourceURL?
            .appendingPathComponent("Scripts")
            .appendingPathComponent(scriptName)
            .path
        let repoScript = "\(FileManager.default.currentDirectoryPath)/scripts/\(scriptName)"
        let script = [bundledScript, repoScript]
            .compactMap { $0 }
            .first { FileManager.default.isExecutableFile(atPath: $0) }

        guard let script else {
            showAlert(
                title: "Script Not Found",
                message: "Could not find \(scriptName) in the app bundle or repository scripts directory."
            )
            completion?(false)
            return
        }

        guard FileManager.default.isExecutableFile(atPath: script) else {
            showAlert(title: "Script Not Found", message: "Could not find executable script at \(script). Run from the repository root for the development installer.")
            completion?(false)
            return
        }

        let command = ([script] + arguments).map(shellQuoted).joined(separator: " ")
        let source = "do shell script \(String(reflecting: command)) with administrator privileges"
        var error: NSDictionary?
        if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
            showAlert(title: "Command Failed", message: error?.description ?? "Unknown AppleScript error")
            completion?(false)
        } else {
            refreshStatus()
            completion?(true)
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
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
        runScript(named: "install-helper.sh") { [weak self] success in
            guard success else {
                return
            }
            self?.promptLaunchAtLoginIfNeeded()
        }
    }

    @objc private func uninstallHelper() {
        runScript(named: "uninstall-helper.sh")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            rebuildMenu(status: lastResponse?.chargeState?.rawValue ?? "Updated")
        } catch {
            showAlert(title: "Launch at Login Failed", message: String(describing: error))
        }
    }

    @objc private func showLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: ChargeLimitPaths.logDirectory))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func launchAtLoginTitle() -> String {
        switch SMAppService.mainApp.status {
        case .requiresApproval:
            return "Launch at Login (Needs Approval)"
        case .notFound:
            return "Launch at Login (Move to Applications)"
        default:
            return "Launch at Login"
        }
    }

    private func launchAtLoginState() -> NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        default:
            return .off
        }
    }

    private func showFirstRunGuidanceIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.didShowFirstRunGuidance) else {
            return
        }

        UserDefaults.standard.set(true, forKey: DefaultsKey.didShowFirstRunGuidance)

        if helperIsAvailable() {
            promptLaunchAtLoginIfNeeded()
            return
        }

        let response = firstRunAlert(
            title: "Install Helper Required",
            message: "ChargeLimiter needs to install a privileged helper before it can read battery state and pause charging. After installing it, you can enable Launch at Login from the menu so the limit stays active after restart.",
            firstButton: "Install Helper",
            secondButton: "Not Now"
        )

        if response == .alertFirstButtonReturn {
            installHelper()
        }
    }

    private func promptLaunchAtLoginIfNeeded() {
        guard SMAppService.mainApp.status != .enabled else {
            return
        }

        let response = firstRunAlert(
            title: "Enable Launch at Login?",
            message: "ChargeLimiter works best when it opens automatically after you sign in, because the menu bar app keeps applying your charge limit policy.",
            firstButton: "Enable",
            secondButton: "Not Now"
        )

        guard response == .alertFirstButtonReturn else {
            return
        }

        do {
            try SMAppService.mainApp.register()
            rebuildMenu(status: lastResponse?.chargeState?.rawValue ?? "Updated")
        } catch {
            showAlert(title: "Launch at Login Failed", message: String(describing: error))
        }
    }

    private func helperIsAvailable() -> Bool {
        (try? service.status()).map { $0.ok } ?? false
    }

    private func firstRunAlert(title: String, message: String, firstButton: String, secondButton: String) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: firstButton)
        alert.addButton(withTitle: secondButton)
        return alert.runModal()
    }
}

private let app = NSApplication.shared
private let delegate = MenuBarApp()
app.delegate = delegate
app.run()
