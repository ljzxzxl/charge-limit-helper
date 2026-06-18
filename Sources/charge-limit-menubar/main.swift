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
    static var continueAction: String { isChinese ? "继续" : "Continue" }
    static var cancel: String { isChinese ? "取消" : "Cancel" }

    static var manualPauseMessage: String {
        isChinese
            ? "手动暂停充电会关闭“启用充电限制”，避免自动策略在下一次刷新时覆盖你的操作。是否继续？"
            : "Manually pausing charging will disable Enable Limit so the automatic policy does not override this action on the next refresh. Continue?"
    }

    static var manualResumeMessage: String {
        isChinese
            ? "手动恢复充电会关闭“启用充电限制”，让系统持续按默认方式充电，直到你再次启用充电限制。是否继续？"
            : "Manually resuming charging will disable Enable Limit so the system keeps charging normally until you enable the limit again. Continue?"
    }

    static func supported(model: String) -> String {
        isChinese ? "已支持：\(model)" : "Supported: \(model)"
    }

    static func target(_ value: Int) -> String {
        isChinese ? "目标电量：\(value)%" : "Target: \(value)%"
    }

    static func status(uiPercent: String, rawPercent: String?, targetPercent: Int, state: String, bclm: String) -> String {
        if let rawPercent {
            return isChinese
                ? "系统 \(uiPercent) · 底层 \(rawPercent) · 目标 \(targetPercent)% · \(state) · BCLM \(bclm)"
                : "UI \(uiPercent) · Raw \(rawPercent) · Target \(targetPercent)% · \(state) · BCLM \(bclm)"
        }

        return isChinese
            ? "系统 \(uiPercent) · 目标 \(targetPercent)% · \(state) · BCLM \(bclm)"
            : "UI \(uiPercent) · Target \(targetPercent)% · \(state) · BCLM \(bclm)"
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
        case .manualActionDisablesLimit:
            return isChinese ? "将停用充电限制" : "Charge Limit Will Be Disabled"
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
        case manualActionDisablesLimit
    }
}

private enum MenuBarIcon {
    private static let logicalSize = NSSize(width: 18, height: 18)

    @MainActor
    static func make(for appearance: NSAppearance?) -> NSImage {
        let imageName = usesDarkAppearance(appearance) ? "MenuBarIconDark" : "MenuBarIconLight"
        let image = loadImage(named: imageName) ?? NSImage(size: logicalSize)
        image.size = logicalSize
        image.isTemplate = false
        return image
    }

    @MainActor
    private static func usesDarkAppearance(_ appearance: NSAppearance?) -> Bool {
        let effectiveAppearance = appearance ?? NSApp.effectiveAppearance
        return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func loadImage(named name: String) -> NSImage? {
        for urls in imageURLSets(named: name) {
            if let image = makeMultiScaleImage(oneX: urls.oneX, twoX: urls.twoX) {
                return image
            }
        }

        return nil
    }

    private static func imageURLSets(named name: String) -> [(oneX: URL?, twoX: URL?)] {
        let bundleURLs = (
            oneX: Bundle.main.url(forResource: name, withExtension: "png"),
            twoX: Bundle.main.url(forResource: "\(name)@2x", withExtension: "png")
        )

        let repoDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("MenuBarIcons")
        let repoURLs = (
            oneX: repoDirectory.appendingPathComponent("\(name).png"),
            twoX: repoDirectory.appendingPathComponent("\(name)@2x.png")
        )

        return [bundleURLs, repoURLs]
    }

    private static func makeMultiScaleImage(oneX: URL?, twoX: URL?) -> NSImage? {
        let image = NSImage(size: logicalSize)
        var didAddRepresentation = false

        for url in [oneX, twoX].compactMap({ $0 }) where FileManager.default.fileExists(atPath: url.path) {
            guard let data = try? Data(contentsOf: url),
                  let representation = NSBitmapImageRep(data: data) else {
                continue
            }
            representation.size = logicalSize
            image.addRepresentation(representation)
            didAddRepresentation = true
        }

        return didAddRepresentation ? image : nil
    }
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
        let uiPercent = response.battery?.uiStateOfCharge.map { "\($0)%" } ?? "--"
        let rawPercent = response.battery?.rawStateOfCharge.map { "\($0)%" }
        let state = L10n.chargeState(ChargeStateResolver.resolve(battery: response.battery, bclm: response.bclm))
        return L10n.status(
            uiPercent: uiPercent,
            rawPercent: rawPercent,
            targetPercent: targetPercent,
            state: state,
            bclm: response.bclm.map(String.init) ?? "?"
        )
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

        button.image = MenuBarIcon.make(for: button.effectiveAppearance)
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = toolTip
    }

    private func write(_ value: UInt8, retryOnRateLimit: Bool = false) {
        do {
            let response = try service.setBCLM(value, allowUnsupported: false)
            if !response.ok {
                if retryOnRateLimit, isRateLimitError(response.error) {
                    scheduleWriteRetry(value)
                } else {
                    showAlert(title: L10n.alertTitle(.writeFailed), message: response.error ?? L10n.helperError)
                }
                refreshStatus()
                return
            }
            refreshStatus()
        } catch {
            showAlert(title: L10n.alertTitle(.writeFailed), message: String(describing: error))
        }
    }

    private func isRateLimitError(_ error: String?) -> Bool {
        error?.localizedCaseInsensitiveContains("rate-limited") == true
    }

    private func scheduleWriteRetry(_ value: UInt8) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            Task { @MainActor in
                self?.write(value, retryOnRateLimit: false)
            }
        }
    }

    private func applyPolicyIfNeeded(response: HelperResponse) {
        guard isEnabled, let battery = response.battery else {
            return
        }

        do {
            let policy = try ChargeLimitPolicy(config: menuBarPolicyConfig())
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

    private func confirm(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.continueAction)
        alert.addButton(withTitle: L10n.cancel)
        return alert.runModal() == .alertFirstButtonReturn
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

        let commandExpression = ([script] + arguments)
            .map { "(quoted form of \(appleScriptStringLiteral($0)))" }
            .joined(separator: " & \" \" & ")
        let source = "do shell script \(commandExpression) with administrator privileges"
        var error: NSDictionary?
        if NSAppleScript(source: source)?.executeAndReturnError(&error) == nil {
            showAlert(title: L10n.alertTitle(.commandFailed), message: error?.description ?? L10n.unknownError)
            completion?(false)
        } else {
            refreshStatus()
            completion?(true)
        }
    }

    private func appleScriptStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
            let policy = try ChargeLimitPolicy(config: menuBarPolicyConfig())
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
        performManualChargeAction(value: 15, message: L10n.manualPauseMessage)
    }

    private func menuBarPolicyConfig() -> ChargeLimitConfig {
        ChargeLimitConfig(targetPercent: targetPercent, resumeAtTargetPercent: true)
    }

    @objc private func resumeCharging() {
        performManualChargeAction(value: 100, message: L10n.manualResumeMessage)
    }

    private func performManualChargeAction(value: UInt8, message: String) {
        if isEnabled {
            guard confirm(title: L10n.alertTitle(.manualActionDisablesLimit), message: message) else {
                return
            }
            isEnabled = false
            rebuildMenu(status: currentMenuStatus())
        }
        write(value, retryOnRateLimit: true)
    }

    private func restoreDefault() {
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
