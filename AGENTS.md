# AGENTS.md

This document is for future Codex sessions and human contributors working on
`charge-limit-helper`.

## Project Goal

Build an open-source macOS charge limiter for Intel MacBooks with the core
AlDente-like behavior:

- Let the Mac charge until a user-selected target percentage.
- Pause charging at the target.
- Resume charging after the battery drops below a hysteresis threshold.
- When the battery starts above the selected target, let it naturally discharge
  down to the target while plugged in, then resume normal charge limiting.
- Eventually ship as a downloadable, signed, notarized Mac menu bar app.

The current repository is a development MVP, not a production-ready app.

## Hardware Validation Background

Validation was performed on:

- MacBook Pro 16-inch 2019
- Model identifier: `MacBookPro16,1`
- Intel CPU
- AppleSMC-backed battery controller
- macOS 26.5.1

Key observed behavior with AlDente exited:

- Writing `BCLM=100` as root allows charging.
- Writing `BCLM=15` as root pauses charging.
- With AC still attached and `BCLM=15`, the machine can naturally discharge.
  In validation, raw state of charge fell while `ExternalConnected=Yes`,
  `ChargingCurrent=0`, and `NotChargingReason=14`.
- At 82% UI battery percentage, writing `BCLM=15` produced a stable state:

```text
82%; AC attached; not charging
ChargingCurrent=0
NotChargingReason=14
IsCharging=No
BCLM=15
```

Important interpretation:

- `BCLM=15` is not a user target of 15%.
- In this validated flow it behaves as a low SMC limit that forces charging to
  pause after the desired target is reached.
- The MVP policy is therefore: write `100` to allow charge, write `15` to pause.
- macOS UI battery percentage can lag behind the raw battery gauge near 100%.
  From v0.1.9 onward, discharge-to-target treats the user-visible macOS
  percentage as the target source of truth, keeps `BCLM=15` at/above the target,
  and only restores `BCLM=100` below the hysteresis threshold. The raw battery
  gauge is only a safety floor, currently `target - 2%`, so the app does not keep
  discharging if the visible percentage is stale.

Active discharge validation:

- The project tested common adapter-disconnect SMC keys seen in public battery
  tools: `CH0B`, `CH0C`, `CHTE`, `CHIE`, `CH0I`, and `CH0J`.
- On `MacBookPro16,1`, `CH0B`, `CH0C`, `CHTE`, `CHIE`, and `CH0I` were not
  present. `CH0J` appeared special but returned `not privileged` for read/write
  even when executed with administrator privileges.
- Do not pursue the simulated-charger-disconnect approach for this model unless
  there is a new, well-contained validation plan.
- The current preferred approach is to keep `BCLM=15` while the macOS visible
  battery percentage is at or above the target. Restore `BCLM=100` only when the
  visible percentage drops below the hysteresis threshold, or earlier if raw SoC
  reaches the safety floor.

## Current Architecture

Swift Package products:

- `ChargeLimitCore`
  - Reads `AppleSmartBattery` via I/O Registry.
  - Reads/writes AppleSMC key `BCLM`.
  - Contains charge limit policy logic.
  - Contains JSON request/response types and Unix socket client code.

- `charge-limit-helperd`
  - Root helper daemon.
  - Can run directly or via launchd.
  - Listens on `/var/run/charge-limit-helper.sock`.
  - Supports `status` and `setBCLM`.
  - Also has development-only raw SMC helpers for validation:
    `smc-read <key>` and a whitelist-limited `smc-write-hex <key> <hex>`.
  - Keeps the privileged API deliberately small.

- `charge-limit-monitor`
  - User-space monitor.
  - Polls helper status.
  - Writes `BCLM=15` at or above target.
  - Writes `BCLM=100` at or below target minus hysteresis.

- `charge-limit`
  - Developer CLI.
  - Commands: `doctor`, `self-test`, `status`, `pause`, `resume`,
    `restore-default`, `set-bclm`, `logs`.

- `charge-limit-menubar`
  - `ChargeLimiter` menu bar app implementation.
  - Shows status and target controls.
  - Calls the current helper transport through `SocketChargeLimitService`.
  - Uses the discharge-to-target policy path: if charge limiting is enabled and
    the visible battery percentage is at or above the target, it holds
    `BCLM=15`; below the hysteresis threshold it writes `BCLM=100`. Raw SoC is
    shown in the menu and used as a lower safety floor.
  - Menu status is split into compact lines: charging/discharging state first,
    visible/raw battery percentages second, compatibility third.
  - Menu bar icon uses both 1x and 2x PNG representations so it stays sharp on
    Retina displays.
  - Manual Pause Charging / Resume Charging disables automatic charge limiting
    after confirmation; if automatic limiting is already disabled, no warning is
    shown.

Supporting files:

- `scripts/install-helper.sh`
- `scripts/uninstall-helper.sh`
- `packaging/launchd/*.plist`
- `docs/architecture.md`
- `docs/validation.md`

Current identifiers:

- App bundle ID: `com.ljzxzxl.ChargeLimiter`
- Helper LaunchDaemon: `com.ljzxzxl.ChargeLimiter.Helper`
- Monitor LaunchAgent: `com.ljzxzxl.ChargeLimiter.Monitor`
- Helper logs: `/Library/Logs/ChargeLimiter`

The older `com.lookslikecode.*` labels only appear in installer/uninstaller
legacy cleanup code for v0.1.0-v0.1.5 and must not be used for new install
artifacts.

## Current Validation

Known-good commands:

```sh
swift build -c release
.build/release/charge-limit self-test
.build/release/charge-limit doctor
.build/release/charge-limit-helperd status
.build/release/charge-limit-helperd smc-read BCLM
./scripts/build-app.sh
./scripts/package-dmg.sh
plutil -lint packaging/launchd/*.plist
```

`swift test` is not currently used because the local SwiftPM environment did
not expose `Testing` or `XCTest`. For now, policy tests live in the CLI
`self-test` command. A future CI/Xcode setup should restore standard tests.

The repository has been pushed to:

```text
git@github.com:ljzxzxl/charge-limit-helper.git
```

## Safety Rules For Future Work

This project writes low-level battery firmware state. Treat write operations as
hardware-affecting.

Before any SMC write:

1. Confirm the target machine is an Intel MacBook with AppleSMC.
2. Read and log current `BCLM`.
3. Read and log battery state using `charge-limit doctor`.
4. Prefer same-value writes or `status` checks first.
5. Keep a clear rollback path: write `BCLM=100` to resume normal charging.

Avoid these unless explicitly requested:

- Do not force-push GitHub history.
- Do not leave temporary root helper daemons running.
- Do not leave the machine in an unknown charging state.
- Do not run broad destructive cleanup commands.

After manual daemon experiments, check:

```sh
ps aux | rg 'charge-limit-helperd|charge-limit-monitor' | rg -v rg
ls -l /var/run/charge-limit-helper.sock 2>/dev/null || true
.build/release/charge-limit doctor
```

After discharge-to-target experiments, additionally check:

```sh
/usr/local/bin/charge-limit status
.build/release/charge-limit-helperd smc-read BCLM
pmset -g batt
```

Safe final state should normally be `BCLM=100` when not actively validating, or
`BCLM=15` only when intentionally testing pause/discharge behavior.

## Near-Term Development Plan

Recommended next milestone: turn the current validation app into a safer
downloadable development release.

1. Finish validating discharge-to-target with target 90% on `MacBookPro16,1`
   using the v0.1.9 visible-percent-primary policy.
2. Decide whether the raw SMC validation commands should remain in the helper,
   be hidden behind a development flag, or be removed before the next release.
3. Add fuller diagnostics for active discharge-to-target mode beyond the compact
   menu status that displays state plus visible/raw percentages.
4. Add fallback recovery documentation.
5. Broaden validation to at least one more Intel MacBook model.

After that, move toward a public app:

1. Replace the MVP Unix socket with XPC.
2. Validate client code signature in the helper.
3. Install the helper via `SMAppService` or an `SMJobBless`-style flow.
4. Add Apple Developer ID signing, notarization, and DMG/PKG packaging.
5. Add compatibility checks and user-facing warnings.
6. Add CI and standard tests.

## Known Limitations

- Intel MacBook only.
- Only validated on `MacBookPro16,1`.
- Current helper authorization is MVP-level Unix socket permission
  (`root:admin`, mode `0660`), not production XPC authorization.
- `ChargeLimiter` menu bar UI exists, but it is still a development UI rather
  than a signed/notarized production app.
- No signed/notarized release.
- No broad model compatibility matrix.
- No automatic recovery service if SMC state is externally changed.
- Discharge-to-target has only been validated on one machine so far. The target
  decision now follows the visible macOS percentage, with raw SoC used as a
  safety floor, but the full behavior still needs broader hardware testing.
- Development raw SMC commands are intentionally whitelist-limited but are still
  privileged hardware controls. They should not be exposed in the production UI.

## Useful Commands

Build:

```sh
swift build -c release
```

Self-test without touching hardware:

```sh
.build/release/charge-limit self-test
```

Read local battery and SMC state:

```sh
.build/release/charge-limit doctor
.build/release/charge-limit-helperd smc-read BCLM
```

Run helper directly for development:

```sh
sudo .build/release/charge-limit-helperd --daemon
```

In another terminal:

```sh
.build/release/charge-limit status
.build/release/charge-limit resume
.build/release/charge-limit pause
```

Run monitor:

```sh
.build/release/charge-limit-monitor --target 82 --verbose
```

Run development menu bar executable:

```sh
.build/release/charge-limit-menubar
```

Run the packaged local app used for validation:

```sh
./scripts/build-app.sh
open build/ChargeLimiter.app
```

Build and package `ChargeLimiter.app`:

```sh
./scripts/build-app.sh
./scripts/package-dmg.sh
```

Install development helper:

```sh
./scripts/install-helper.sh
```

Uninstall development helper:

```sh
./scripts/uninstall-helper.sh
```

## Source Map

- `Sources/ChargeLimitCore/SMC.swift`: AppleSMC read/write implementation.
- `Sources/ChargeLimitCore/Battery.swift`: `AppleSmartBattery` snapshot.
- `Sources/ChargeLimitCore/ChargeLimitPolicy.swift`: pause/resume and
  discharge-to-target decision logic.
- `Sources/ChargeLimitCore/UnixSocket.swift`: MVP helper transport.
- `Sources/ChargeLimitHelper/main.swift`: root helper daemon.
- `Sources/charge-limit-monitor/main.swift`: user-space monitor.
- `Sources/charge-limit/main.swift`: developer CLI.
- `Sources/charge-limit-menubar/main.swift`: `ChargeLimiter` menu bar app.
- `docs/validation.md`: hardware validation notes.
- `docs/architecture.md`: architecture notes.
