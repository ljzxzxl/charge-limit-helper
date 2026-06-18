import AppKit
import ChargeLimitCore
import Foundation
import ServiceManagement

private enum DefaultsKey {
    static let targetPercent = "targetPercent"
    static let enabled = "enabled"
    static let didShowFirstRunGuidance = "didShowFirstRunGuidance"
}

private enum L10n {
    private static var isChinese: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
    }

    static var loading: String { isChinese ? "正在加载..." : "Loading..." }
    static var updated: String { isChinese ? "已更新" : "Updated" }
    static var helperUnavailable: String { isChinese ? "Helper 不可用" : "Helper unavailable" }
    static var helperError: String { isChinese ? "Helper 错误" : "Helper error" }
    static var unsupportedOrUnverified: String { isChinese ? "不支持或未验证" : "Unsupported or unverified" }
    static var enableLimit: String { isChinese ? "启用充电限制" : "Enable Limit" }
    static var pauseCharging: String { isChinese ? "暂停充电" : "Pause Charging" }
    static var resumeCharging: String { isChinese ? "恢复充电" : "Resume Charging" }
    static var restoreDefault: String { isChinese ? "恢复默认充电" : "Restore Default" }
    static var installHelper: String { isChinese ? "安装 Helper" : "Install Helper" }
    static var uninstallHelper: String { isChinese ? "卸载 Helper" : "Uninstall Helper" }
    static var showLogs: String { isChinese ? "显示日志" : "Show Logs" }
    static var quit: String { isChinese ? "退出" : "Quit" }
    static var launchAtLogin: String { isChinese ? "开机自启" : "Launch at Login" }
    static var launchAtLoginNeedsApproval: String { isChinese ? "开机自启（需要批准）" : "Launch at Login (Needs Approval)" }
    static var launchAtLoginMoveToApplications: String { isChinese ? "开机自启（请移到“应用程序”）" : "Launch at Login (Move to Applications)" }
    static var noBatteryData: String { isChinese ? "没有电池数据" : "No battery data" }
    static var unknownError: String { isChinese ? "未知 AppleScript 错误" : "Unknown AppleScript error" }
    static var notNow: String { isChinese ? "暂不" : "Not Now" }
    static var enable: String { isChinese ? "开启" : "Enable" }

    static func supported(model: String) -> String {
        isChinese ? "已支持：\(model)" : "Supported: \(model)"
    }

    static func target(_ value: Int) -> String {
        isChinese ? "目标电量：\(value)%" : "Target: \(value)%"
    }

    static func chargeState(_ state: ChargeState?) -> String {
        switch state {
        case .charging:
            return isChinese ? "正在充电" : "Charging"
        case .paused:
            return isChinese ? "已暂停充电" : "Paused"
        case .onBattery:
            return isChinese ? "使用电池" : "On Battery"
        case .full:
            return isChinese ? "已充满" : "Full"
        case .unknown, nil:
            return isChinese ? "未知" : "Unknown"
        }
    }

    static func alertTitle(_ key: AlertTitle) -> String {
        switch key {
        case .writeFailed:
            return isChinese ? "写入失败" : "Write Failed"
        case .scriptNotFound:
            return isChinese ? "找不到脚本" : "Script Not Found"
        case .commandFailed:
            return isChinese ? "命令执行失败" : "Command Failed"
        case .statusFailed:
            return isChinese ? "读取状态失败" : "Status Failed"
        case .applyFailed:
            return isChinese ? "应用策略失败" : "Apply Failed"
        case .restoreFailed:
            return isChinese ? "恢复失败" : "Restore Failed"
        case .launchAtLoginFailed:
            return isChinese ? "开机自启设置失败" : "Launch at Login Failed"
        case .installHelperRequired:
            return isChinese ? "需要安装 Helper" : "Install Helper Required"
        case .enableLaunchAtLogin:
            return isChinese ? "开启开机自启？" : "Enable Launch at Login?"
        }
    }

    static var missingScriptMessage: String {
        isChinese
            ? "无法在 App bundle 或仓库 scripts 目录中找到安装脚本。"
            : "Could not find the script in the app bundle or repository scripts directory."
    }

    static func nonExecutableScriptMessage(_ path: String) -> String {
        isChinese
            ? "脚本不可执行：\(path)。如果是开发环境，请从仓库根目录运行。"
            : "Could not find executable script at \(path). Run from the repository root for the development installer."
    }

    static var firstRunHelperMessage: String {
        isChinese
            ? "ChargeLimiter 需要先安装 privileged helper，才能读取电池状态并暂停充电。安装完成后，你可以开启开机自启，让充电限制在重启或重新登录后继续生效。"
            : "ChargeLimiter needs to install a privileged helper before it can read battery state and pause charging. After installing it, you can enable Launch at Login so the limit stays active after restart."
    }

    static var launchAtLoginMessage: String {
        isChinese
            ? "建议让 ChargeLimiter 登录后自动启动，这样菜单栏程序可以持续应用你的充电限制策略。"
            : "ChargeLimiter works best when it opens automatically after you sign in, because the menu bar app keeps applying your charge limit policy."
    }

    enum AlertTitle {
        case writeFailed
        case scriptNotFound
        case commandFailed
        case statusFailed
        case applyFailed
        case restoreFailed
        case launchAtLoginFailed
        case installHelperRequired
        case enableLaunchAtLogin
    }
}

private enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()

            let bolt = NSBezierPath()
            bolt.move(to: NSPoint(x: 7.7, y: 16.4))
            bolt.line(to: NSPoint(x: 10.8, y: 16.4))
            bolt.line(to: NSPoint(x: 8.5, y: 10.2))
            bolt.line(to: NSPoint(x: 10.9, y: 10.2))
            bolt.line(to: NSPoint(x: 5.0, y: 1.4))
            bolt.line(to: NSPoint(x: 6.4, y: 8.3))
            bolt.line(to: NSPoint(x: 3.2, y: 8.3))
            bolt.close()
            bolt.fill()

            let firstPause = NSBezierPath(
                roundedRect: NSRect(x: 12.3, y: 3.4, width: 2.1, height: 11.2),
                xRadius: 1.05,
                yRadius: 1.05
            )
            firstPause.fill()

            let secondPause = NSBezierPath(
                roundedRect: NSRect(x: 15.4, y: 3.4, width: 2.1, height: 11.2),
                xRadius: 1.05,
                yRadius: 1.05
            )
            secondPause.fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}

@MainActor
private final class MenuBarApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menuIcon = MenuBarIcon.make()
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
        statusItem.length = NSStatusItem.squareLength
        configureStatusItem(toolTip: L10n.loading)
        rebuildMenu(status: L10n.loading)
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
                let status = statusText(for: response)
                configureStatusItem(toolTip: status)
                rebuildMenu(status: status)
            } else {
                let status = response.error ?? L10n.helperError
                configureStatusItem(toolTip: status)
                rebuildMenu(status: status)
            }
        } catch {
            configureStatusItem(toolTip: L10n.helperUnavailable)
            rebuildMenu(status: L10n.helperUnavailable)
        }
    }

    private func statusText(for response: HelperResponse) -> String {
        let percent = response.battery?.uiStateOfCharge.map { "\($0)%" } ?? "--"
        let state = L10n.chargeState(response.chargeState)
        return "\(percent) · \(state) · BCLM \(response.bclm.map(String.init) ?? "?")"
    }

    private func currentMenuStatus() -> String {
        guard let lastResponse else {
            return L10n.updated
        }
        if lastResponse.ok {
            return statusText(for: lastResponse)
        }
        return lastResponse.error ?? L10n.helperError
    }

    private func rebuildMenu(status: String) {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if let compatibility = lastResponse?.compatibility {
            let model = compatibility.modelIdentifier ?? "Mac"
            let item = NSMenuItem(title: compatibility.isSupported ? L10n.supported(model: model) : L10n.unsupportedOrUnverified, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let enabled = NSMenuItem(title: L10n.enableLimit, action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = isEnabled ? .on : .off
        enabled.target = self
        menu.addItem(enabled)

        let target = NSMenuItem(title: L10n.target(targetPercent), action: nil, keyEquivalent: "")
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

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: launchAtLoginTitle(), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.state = launchAtLoginState()
        launchAtLogin.target = self
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())

        let pause = NSMenuItem(title: L10n.pauseCharging, action: #selector(pauseCharging), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let resume = NSMenuItem(title: L10n.resumeCharging, action: #selector(resumeCharging), keyEquivalent: "")
        resume.target = self
        menu.addItem(resume)

        let restore = NSMenuItem(title: L10n.restoreDefault, action: #selector(restoreDefault), keyEquivalent: "")
        restore.target = self
        menu.addItem(restore)

        menu.addItem(.separator())

        let install = NSMenuItem(title: L10n.installHelper, action: #selector(installHelper), keyEquivalent: "")
        install.target = self
        menu.addItem(install)

        let uninstall = NSMenuItem(title: L10n.uninstallHelper, action: #selector(uninstallHelper), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)

        let logs = NSMenuItem(title: L10n.showLogs, action: #selector(showLogs), keyEquivalent: "")
        logs.target = self
        menu.addItem(logs)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        self.statusItem.menu = menu
    }

    private func configureStatusItem(toolTip: String) {
        guard let button = statusItem.button else {
            return
        }

        button.image = menuIcon
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = toolTip
    }

    private func write(_ value: UInt8) {
        do {
            _ = try service.setBCLM(value, allowUnsupported: false)
            refreshStatus()
        } catch {
            showAlert(title: L10n.alertTitle(.writeFailed), message: String(describing: error))
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
                title: L10n.alertTitle(.scriptNotFound),
                message: L10n.missingScriptMessage
            )
            completion?(false)
            return
        }

        guard FileManager.default.isExecutableFile(atPath: script) else {
            showAlert(title: L10n.alertTitle(.scriptNotFound), message: L10n.nonExecutableScriptMessage(script))
            completion?(false)
            return
        }

        let command = ([script] + arguments).map(shellQuoted).joined(separator: " ")
        let source = "do shell script \(String(reflecting: command)) with administrator privileges"
        var error: NSDictionary?
        if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
            showAlert(title: L10n.alertTitle(.commandFailed), message: error?.description ?? L10n.unknownError)
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
        if isEnabled {
            applyCurrentPolicy(showErrors: true)
        } else {
            restoreDefault()
        }
    }

    @objc private func setTarget(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Int {
            targetPercent = value
            applyCurrentPolicy(showErrors: true)
        }
    }

    private func applyCurrentPolicy(showErrors: Bool) {
        guard isEnabled else {
            return
        }
        do {
            let response = try service.status()
            guard response.ok, let battery = response.battery else {
                if showErrors {
                    showAlert(title: L10n.alertTitle(.statusFailed), message: response.error ?? L10n.noBatteryData)
                }
                return
            }
            let policy = try ChargeLimitPolicy(config: ChargeLimitConfig(targetPercent: targetPercent))
            let decision = try policy.decide(snapshot: battery, currentBCLM: response.bclm)
            if let value = decision.desiredSMCValue {
                _ = try service.setBCLM(value, allowUnsupported: false)
            }
            refreshStatus()
        } catch {
            if showErrors {
                showAlert(title: L10n.alertTitle(.applyFailed), message: String(describing: error))
            }
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
            showAlert(title: L10n.alertTitle(.restoreFailed), message: String(describing: error))
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
            rebuildMenu(status: currentMenuStatus())
        } catch {
            showAlert(title: L10n.alertTitle(.launchAtLoginFailed), message: String(describing: error))
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
            return L10n.launchAtLoginNeedsApproval
        case .notFound:
            return L10n.launchAtLoginMoveToApplications
        default:
            return L10n.launchAtLogin
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
            title: L10n.alertTitle(.installHelperRequired),
            message: L10n.firstRunHelperMessage,
            firstButton: L10n.installHelper,
            secondButton: L10n.notNow
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
            title: L10n.alertTitle(.enableLaunchAtLogin),
            message: L10n.launchAtLoginMessage,
            firstButton: L10n.enable,
            secondButton: L10n.notNow
        )

        guard response == .alertFirstButtonReturn else {
            return
        }

        do {
            try SMAppService.mainApp.register()
            rebuildMenu(status: currentMenuStatus())
        } catch {
            showAlert(title: L10n.alertTitle(.launchAtLoginFailed), message: String(describing: error))
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
