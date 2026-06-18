# charge-limit-helper

An open-source Intel MacBook charge limiter MVP.

This project implements the core behavior behind a simple AlDente-like charge
limit on Intel MacBooks:

- `BCLM=100` allows charging.
- `BCLM=15` pauses charging after the target UI battery percentage is reached.
- A user-space monitor decides when to switch between those two states.
- A root helper daemon performs the actual AppleSMC write.

The project is intentionally split into small pieces so it can grow into a
proper menu bar macOS app later.

## Current Status

Validated on:

- MacBook Pro 16-inch 2019, `MacBookPro16,1`
- Intel CPU, AppleSMC-backed battery controller
- macOS 26.5.1

Known current limitations:

- Intel MacBooks only.
- The helper daemon uses a local Unix socket for the MVP.
- The future packaged app should use Apple's ServiceManagement flow and code
  signing before broad distribution.
- This is low-level battery firmware control. Use at your own risk.

## Build

```sh
swift build -c release
.build/release/charge-limit self-test
```

## Local Commands

Read local battery and SMC state without the helper:

```sh
.build/release/charge-limit doctor
.build/release/charge-limit self-test
```

Run the helper directly for development:

```sh
sudo .build/release/charge-limit-helperd --daemon
```

In another terminal:

```sh
.build/release/charge-limit status
.build/release/charge-limit resume
.build/release/charge-limit pause
```

Run the monitor with an 82% target:

```sh
.build/release/charge-limit-monitor --target 82 --verbose
```

## Install Helper for Development

```sh
./scripts/install-helper.sh
```

This installs:

- `/Library/PrivilegedHelperTools/charge-limit-helperd`
- `/Library/LaunchDaemons/com.lookslikecode.ChargeLimitHelper.plist`
- `/var/run/charge-limit-helper.sock`

Remove it with:

```sh
./scripts/uninstall-helper.sh
```

## Architecture

```mermaid
flowchart LR
    App["Future menu bar app"] --> Monitor["charge-limit-monitor"]
    CLI["charge-limit CLI"] --> Helper["root helper daemon"]
    Monitor --> Helper
    Helper --> SMC["AppleSMC BCLM key"]
    Helper --> Battery["AppleSmartBattery I/O Registry"]
```

## Roadmap

- Build a SwiftUI menu bar app.
- Add a secure ServiceManagement installer for the helper.
- Replace the MVP socket authorization with code-signature-validated XPC.
- Add settings storage, launch-at-login, and live status UI.
- Add hardware compatibility reporting for Intel MacBook models.

## References

- Apple ServiceManagement `SMAppService`: https://developer.apple.com/documentation/servicemanagement/smappservice
- Apple `SMJobBless`: https://developer.apple.com/documentation/servicemanagement/smjobbless%28_%3A_%3A_%3A_%3A%29
- Apple IOKit: https://developer.apple.com/documentation/iokit
- bclm: https://github.com/zackelia/bclm

## License

MIT. See `LICENSE` and `NOTICE`.
