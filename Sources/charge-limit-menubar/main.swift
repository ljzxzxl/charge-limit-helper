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
    static var ok: String { isChinese ? "好的" : "OK" }
    static var openRelease: String { isChinese ? "打开 Release 页面" : "Open Release Page" }
    static var checkForUpdates: String { isChinese ? "检查更新" : "Check for Updates" }
    static var checkingForUpdates: String { isChinese ? "正在检查更新..." : "Checking for Updates..." }
    static var updateAvailableTitle: String { isChinese ? "发现新版本" : "Update Available" }
    static var noUpdateAvailableTitle: String { isChinese ? "已经是最新版本" : "You're Up to Date" }
    static var updateCheckFailedTitle: String { isChinese ? "检查更新失败" : "Update Check Failed" }

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

    static func version(_ value: String) -> String {
        isChinese ? "版本：\(value)" : "Version: \(value)"
    }

    static func currentVersionSuffix(_ value: String) -> String {
        isChinese ? "(当前 \(value))" : "(Current \(value))"
    }

    static func updateAvailableMessage(current: String, latest: String) -> String {
        isChinese
            ? "当前版本：\(current)\n最新版本：\(latest)\n\n是否打开 GitHub Release 页面手动下载新版？"
            : "Current version: \(current)\nLatest version: \(latest)\n\nOpen the GitHub Release page to download the new version manually?"
    }

    static func noUpdateAvailableMessage(current: String) -> String {
        isChinese
            ? "当前版本 \(current) 已经是最新版本。"
            : "Version \(current) is the latest available release."
    }

    static func updateCheckFailedMessage(_ error: String) -> String {
        isChinese
            ? "无法连接 GitHub Releases 或解析版本信息。\n\n\(error)"
            : "Could not connect to GitHub Releases or parse version information.\n\n\(error)"
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

    static func stateStatus(_ state: String, bclm: String) -> String {
        isChinese ? "状态：\(state) · BCLM \(bclm)" : "Status: \(state) · BCLM \(bclm)"
    }

    static var dischargingToTarget: String {
        isChinese ? "正在放电" : "Discharging"
    }

    static var waitingToCharge: String {
        isChinese ? "等待充电" : "Waiting to Charge"
    }

    static func batteryStatus(uiPercent: String, rawPercent: String?) -> String {
        if let rawPercent {
            return isChinese
                ? "电量：系统 \(uiPercent) · 底层 \(rawPercent)"
                : "Battery: UI \(uiPercent) · Raw \(rawPercent)"
        }

        return isChinese
            ? "电量：系统 \(uiPercent)"
            : "Battery: UI \(uiPercent)"
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

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct SemanticVersion: Comparable {
    let components: [Int]

    init(_ value: String) {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        let versionCore = cleaned.split(separator: "-", maxSplits: 1).first.map(String.init) ?? cleaned
        let parsed = versionCore.split(separator: ".").map { part in
            let digits = part.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
        components = parsed.isEmpty ? [0] : parsed
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private enum UpdateCheckError: LocalizedError {
    case invalidResponse
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid GitHub response."
        case let .badStatus(statusCode):
            return "GitHub returned HTTP \(statusCode)."
        }
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
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/ljzxzxl/charge-limit-helper/releases/latest")!
    private var timer: Timer?
    private var lastResponse: HelperResponse?
    private var isCheckingForUpdates = false

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

    private var appVersion: String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleVersion
        }

        let versionURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("VERSION")
        if let version = try? String(contentsOf: versionURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty {
            return version
        }

        return "0.0.0"
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
                rebuildMenu(statusLines: menuStatusLines(for: response))
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
        let state = displayState(for: response)
        return L10n.status(
            uiPercent: uiPercent,
            rawPercent: rawPercent,
            targetPercent: targetPercent,
            state: state,
            bclm: response.bclm.map(String.init) ?? "?"
        )
    }

    private func menuStatusLines(for response: HelperResponse) -> [String] {
        let uiPercent = response.battery?.uiStateOfCharge.map { "\($0)%" } ?? "--"
        let rawPercent = response.battery?.rawStateOfCharge.map { "\($0)%" }
        let state = displayState(for: response)
        let bclm = response.bclm.map(String.init) ?? "?"
        return [
            L10n.stateStatus(state, bclm: bclm),
            L10n.batteryStatus(uiPercent: uiPercent, rawPercent: rawPercent)
        ]
    }

    private func displayState(for response: HelperResponse) -> String {
        if isDischargingToTarget(response) {
            return L10n.dischargingToTarget
        }

        if isWaitingToCharge(response) {
            return L10n.waitingToCharge
        }

        return L10n.chargeState(ChargeStateResolver.resolve(battery: response.battery, bclm: response.bclm))
    }

    private func isDischargingToTarget(_ response: HelperResponse) -> Bool {
        guard isEnabled,
              response.bclm == 15,
              let battery = response.battery,
              battery.externalConnected == true,
              let uiPercent = battery.uiStateOfCharge else {
            return false
        }

        guard uiPercent > targetPercent else {
            return false
        }

        let batteryAmperage = battery.amperage ?? battery.instantAmperage
        let isNotCharging = battery.isCharging == false
        let hasNoChargeCurrent = battery.chargingCurrent == 0 || battery.notChargingReason == 14
        let isDischarging = batteryAmperage.map { $0 <= 0 } ?? false

        return isNotCharging || hasNoChargeCurrent || isDischarging
    }

    private func isWaitingToCharge(_ response: HelperResponse) -> Bool {
        guard response.bclm == 100,
              let battery = response.battery,
              battery.externalConnected == true,
              battery.fullyCharged != true else {
            return false
        }

        let batteryAmperage = battery.amperage ?? battery.instantAmperage
        let isNotCharging = battery.isCharging == false
        let hasNoChargeCurrent = battery.chargingCurrent == 0 || battery.notChargingReason == 14
        let isDischargingOrIdle = batteryAmperage.map { $0 <= 0 } ?? false

        return isNotCharging || hasNoChargeCurrent || isDischargingOrIdle
    }

    private func currentMenuStatusLines() -> [String] {
        guard let lastResponse else {
            return [L10n.updated]
        }
        if lastResponse.ok {
            return menuStatusLines(for: lastResponse)
        }
        return [lastResponse.error ?? L10n.helperError]
    }

    private func rebuildMenu(status: String) {
        rebuildMenu(statusLines: [status])
    }

    private func rebuildMenu(statusLines: [String]) {
        let menu = NSMenu()

        for line in statusLines {
            let statusItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        }

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

        let updateTitle = isCheckingForUpdates ? L10n.checkingForUpdates : L10n.checkForUpdates
        let updates = NSMenuItem(title: updateTitle, action: #selector(checkForUpdates), keyEquivalent: "")
        updates.attributedTitle = updateMenuItemTitle(updateTitle)
        updates.target = self
        updates.isEnabled = !isCheckingForUpdates
        menu.addItem(updates)

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

    private func updateMenuItemTitle(_ title: String) -> NSAttributedString {
        let suffix = L10n.currentVersionSuffix(appVersion)
        let fullTitle = "\(title) \(suffix)"
        let attributed = NSMutableAttributedString(
            string: fullTitle,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
        )
        let suffixRange = (fullTitle as NSString).range(of: suffix, options: .backwards)
        attributed.addAttributes(
            [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.disabledControlTextColor
            ],
            range: suffixRange
        )
        return attributed
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
        NSApp.activate(ignoringOtherApps: true)
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
            rebuildMenu(statusLines: currentMenuStatusLines())
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

    @objc private func checkForUpdates() {
        guard !isCheckingForUpdates else {
            return
        }

        isCheckingForUpdates = true
        rebuildMenu(statusLines: currentMenuStatusLines())

        Task { @MainActor in
            defer {
                isCheckingForUpdates = false
                rebuildMenu(statusLines: currentMenuStatusLines())
            }

            do {
                let release = try await fetchLatestRelease()
                let currentVersion = appVersion
                let latestVersion = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                if SemanticVersion(latestVersion) > SemanticVersion(currentVersion) {
                    showUpdateAvailableAlert(current: currentVersion, latest: latestVersion, releaseURL: release.htmlURL)
                } else {
                    showInformationalAlert(
                        title: L10n.noUpdateAvailableTitle,
                        message: L10n.noUpdateAvailableMessage(current: currentVersion)
                    )
                }
            } catch {
                showAlert(
                    title: L10n.updateCheckFailedTitle,
                    message: L10n.updateCheckFailedMessage(error.localizedDescription)
                )
            }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ChargeLimiter/\(appVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.badStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    private func showUpdateAvailableAlert(current: String, latest: String, releaseURL: URL) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle
        alert.informativeText = L10n.updateAvailableMessage(current: current, latest: latest)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.openRelease)
        alert.addButton(withTitle: L10n.cancel)

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releaseURL)
        }
    }

    private func showInformationalAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            rebuildMenu(statusLines: currentMenuStatusLines())
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
            rebuildMenu(statusLines: currentMenuStatusLines())
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
