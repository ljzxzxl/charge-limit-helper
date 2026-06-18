# AGENTS.md

This document is for future Codex sessions and human contributors working on
`charge-limit-helper`.

## Project Goal

Build an open-source macOS charge limiter for Intel MacBooks with the core
AlDente-like behavior:

- Let the Mac charge until a user-selected target percentage.
- Pause charging at the target.
- Resume charging after the battery drops below a hysteresis threshold.
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
  - Development menu bar UI scaffold.
  - Shows status and target controls.
  - Calls the current helper transport through `SocketChargeLimitService`.

Supporting files:

- `scripts/install-helper.sh`
- `scripts/uninstall-helper.sh`
- `packaging/launchd/*.plist`
- `docs/architecture.md`
- `docs/validation.md`

## Current Validation

Known-good commands:

```sh
swift build -c release
.build/release/charge-limit self-test
.build/release/charge-limit doctor
.build/release/charge-limit-helperd status
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

## Near-Term Development Plan

Recommended next milestone: development install loop.

1. Verify `scripts/install-helper.sh` installs the helper LaunchDaemon.
2. Verify `.build/release/charge-limit status` talks to the daemon socket.
3. Verify `charge-limit-monitor --target 82 --verbose` can pause/resume without
   AlDente running.
4. Improve logging and failure handling.
5. Add uninstall behavior that restores `BCLM=100`.

After that, move toward a public app:

1. Build a SwiftUI menu bar app.
2. Replace the MVP Unix socket with XPC.
3. Validate client code signature in the helper.
4. Install the helper via `SMAppService` or an `SMJobBless`-style flow.
5. Add Apple Developer ID signing, notarization, and DMG/PKG packaging.
6. Add compatibility checks and user-facing warnings.
7. Add CI and standard tests.

## Known Limitations

- Intel MacBook only.
- Only validated on `MacBookPro16,1`.
- Current helper authorization is MVP-level Unix socket permission
  (`root:admin`, mode `0660`), not production XPC authorization.
- No GUI yet.
- No signed/notarized release.
- No broad model compatibility matrix.
- No automatic recovery service if SMC state is externally changed.

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

Run development menu bar scaffold:

```sh
.build/release/charge-limit-menubar
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
- `Sources/ChargeLimitCore/ChargeLimitPolicy.swift`: pause/resume decision logic.
- `Sources/ChargeLimitCore/UnixSocket.swift`: MVP helper transport.
- `Sources/ChargeLimitHelper/main.swift`: root helper daemon.
- `Sources/charge-limit-monitor/main.swift`: user-space monitor.
- `Sources/charge-limit/main.swift`: developer CLI.
- `Sources/charge-limit-menubar/main.swift`: development menu bar scaffold.
- `docs/validation.md`: hardware validation notes.
- `docs/architecture.md`: architecture notes.
