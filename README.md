# ChargeLimiter

[English](#english) | [中文](#中文)

## English

ChargeLimiter is a small macOS menu bar app for Intel MacBooks. It provides the
core AlDente-like behavior: when your battery reaches the configured target, it
pauses charging through the Intel Mac AppleSMC `BCLM` key; when the battery drops
below the hysteresis threshold, it resumes charging.

This project is intentionally focused on the narrow hardware gap where macOS
does not provide a user-selectable charge limit for Intel MacBooks.

### Compatibility

Supported target:

- macOS 13 Ventura or later.
- Intel MacBook models with an internal battery and AppleSMC battery controller.
- Validated so far on MacBook Pro 16-inch 2019, `MacBookPro16,1`, macOS 26.5.1.

Not supported:

- Apple Silicon MacBooks. The SMC control path used by this app is Intel-only.
  Apple Silicon models should use macOS built-in Battery settings such as
  Optimized Battery Charging and Charge Limit where available.
- iMac, Mac mini, Mac Studio, Mac Pro, or any desktop Mac. They do not have a
  laptop battery to limit.
- Hackintosh or non-Apple battery controllers.

### Download

Download the latest `ChargeLimiter-*.dmg` from
[GitHub Releases](https://github.com/ljzxzxl/charge-limit-helper/releases), open
it, drag `ChargeLimiter.app` to the Applications folder, then run it.

On first launch, ChargeLimiter will explain that a privileged helper is required.
Choose **Install Helper** and enter your administrator password. After the helper
is installed, the app will guide you to enable **Launch at Login** so the charge
limit remains active after you restart or sign in again.

### What It Does

- Reads battery state from AppleSmartBattery.
- Writes AppleSMC `BCLM=15` to pause charging.
- Writes AppleSMC `BCLM=100` to resume normal charging.
- Applies a target percentage policy from the menu bar.
- Installs a root helper daemon for the low-level SMC write.
- Provides a Launch at Login toggle for the menu bar controller.

It does not collect telemetry, upload data, or modify unrelated system settings.

### Current Limitations

- The current DMG is a development package with ad-hoc signing.
- Broad distribution still needs Developer ID signing, notarization, and a
  production ServiceManagement helper installation flow.
- The helper daemon currently uses a local Unix socket for the MVP.
- This is low-level battery firmware control. Use at your own risk.

### Build

Requirements:

- macOS 13 or later
- Xcode Command Line Tools

```sh
git clone git@github.com:ljzxzxl/charge-limit-helper.git
cd charge-limit-helper
swift build -c release
.build/release/charge-limit self-test
```

Build the menu bar app bundle:

```sh
./scripts/build-app.sh
```

The built app will be written to:

```text
build/ChargeLimiter.app
```

### Package

```sh
./scripts/package-dmg.sh
```

This creates a DMG archive and SHA256 checksum file in `dist/`. Tagged pushes
create GitHub Release assets through `.github/workflows/build.yml`.

### Development Commands

Read local battery and SMC state without the helper:

```sh
.build/release/charge-limit doctor
.build/release/charge-limit self-test
```

Install the development helper:

```sh
./scripts/install-helper.sh
```

Remove it:

```sh
./scripts/uninstall-helper.sh
```

Run the packaged app after `build-app.sh`:

```sh
open build/ChargeLimiter.app
```

### References

- Apple Optimized Battery Charging and Charge Limit:
  https://support.apple.com/en-us/102338
- Apple battery health management for Apple Silicon Mac laptops:
  https://support.apple.com/en-us/102589
- Apple ServiceManagement `SMAppService`:
  https://developer.apple.com/documentation/servicemanagement/smappservice
- bclm:
  https://github.com/zackelia/bclm

### License

MIT. See `LICENSE` and `NOTICE`.

## 中文

ChargeLimiter 是一个很小的 macOS 菜单栏工具，目标是给 Intel MacBook 提供类似
AlDente 的核心充电限制能力：当电池达到你设置的目标百分比后，通过 Intel Mac 的
AppleSMC `BCLM` 键暂停充电；当电量低于回差阈值后，再恢复正常充电。

这个项目专门面向 Intel MacBook 这类系统没有提供“手动指定充电上限”的场景。

### 兼容性

支持目标：

- macOS 13 Ventura 或更高版本。
- 带内置电池、并使用 AppleSMC 电池控制器的 Intel MacBook。
- 目前已在 MacBook Pro 16-inch 2019，`MacBookPro16,1`，macOS 26.5.1 上验证。

不支持：

- Apple Silicon MacBook。这个项目使用的 SMC 控制路径只适用于 Intel Mac。M 芯片
  MacBook 用户建议直接使用系统“电池”设置里的“优化电池充电”以及系统可用时的
  “充电限制”功能，无需安装本软件。
- iMac、Mac mini、Mac Studio、Mac Pro 等台式机。它们没有需要限制充电的内置笔记本电池。
- 黑苹果或非 Apple 原厂电池控制器。

### 下载使用

到 [GitHub Releases](https://github.com/ljzxzxl/charge-limit-helper/releases)
下载最新的 `ChargeLimiter-*.dmg`，打开后把 `ChargeLimiter.app` 拖到“应用程序”
中，再运行它。

首次运行时，ChargeLimiter 会提示你需要安装 privileged helper 才能正常读取电池状态
并暂停充电。选择 **Install Helper** 后输入管理员密码即可。安装完成后，App 会继续
引导你开启 **Launch at Login**，这样每次开机登录后都会自动启动菜单栏程序，充电限制
策略也能持续生效。

第一次打开时，如果 macOS 提示无法验证开发者，可以在 Finder 里右键点击 App，选择
**打开**，再确认一次。后续就可以直接双击运行。

### 它会做什么

- 从 AppleSmartBattery 读取电池状态。
- 写入 AppleSMC `BCLM=15` 来暂停充电。
- 写入 AppleSMC `BCLM=100` 来恢复正常充电。
- 在菜单栏中应用目标电量策略。
- 安装一个 root helper daemon 负责底层 SMC 写入。
- 提供“开机自启 / Launch at Login”菜单开关。

它不会收集遥测数据，不会上传任何信息，也不会修改无关的系统设置。

### 当前限制

- 当前 DMG 仍是 ad-hoc 签名的开发版本。
- 面向更多用户公开分发前，还需要 Developer ID 签名、notarization，以及正式的
  ServiceManagement helper 安装流程。
- 当前 helper daemon 仍使用本地 Unix socket 作为 MVP 通信方式。
- 这是底层电池固件控制，请自行承担使用风险。

### 从源码构建

要求：

- macOS 13 或更高版本
- Xcode Command Line Tools

```sh
git clone git@github.com:ljzxzxl/charge-limit-helper.git
cd charge-limit-helper
swift build -c release
.build/release/charge-limit self-test
```

构建菜单栏 App：

```sh
./scripts/build-app.sh
```

构建后的 App 会生成在：

```text
build/ChargeLimiter.app
```

### 打包

```sh
./scripts/package-dmg.sh
```

脚本会在 `dist/` 目录生成 DMG 文件和对应的 SHA256 校验文件。推送 tag 时，
`.github/workflows/build.yml` 会自动生成 GitHub Release 附件。

### 开发命令

不通过 helper 读取本机电池和 SMC 状态：

```sh
.build/release/charge-limit doctor
.build/release/charge-limit self-test
```

安装开发 helper：

```sh
./scripts/install-helper.sh
```

卸载：

```sh
./scripts/uninstall-helper.sh
```

运行打包后的 App：

```sh
open build/ChargeLimiter.app
```

### 参考

- Apple 优化电池充电与充电限制：
  https://support.apple.com/en-us/102338
- Apple Silicon Mac 笔记本的电池健康管理：
  https://support.apple.com/en-us/102589
- Apple ServiceManagement `SMAppService`：
  https://developer.apple.com/documentation/servicemanagement/smappservice
- bclm：
  https://github.com/zackelia/bclm

### 许可证

MIT。见 `LICENSE` 和 `NOTICE`。
