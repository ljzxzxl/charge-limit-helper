# TODO.md

This roadmap tracks the path from the current development MVP to a downloadable
Mac app for Intel MacBooks.

## Phase 0: Current MVP Baseline

- [x] Validate SMC behavior on an Intel MacBook.
- [x] Confirm `BCLM=100` allows charging.
- [x] Confirm `BCLM=15` pauses charging at the target percentage.
- [x] Create Swift Package project.
- [x] Implement `ChargeLimitCore`.
- [x] Implement root helper daemon MVP.
- [x] Implement user-space monitor MVP.
- [x] Implement developer CLI.
- [x] Add development launchd templates.
- [x] Add README, architecture notes, validation notes, and AGENTS handoff.
- [x] Push repository to GitHub.
- [x] Rename app/helper identifiers to `com.ljzxzxl.ChargeLimiter.*`.
- [x] Publish development DMG releases through `v0.1.6`.

## Phase 1: Development Install Loop

Goal: install the current helper locally and prove the full daemon + monitor
loop works without AlDente.

- [x] Verify `scripts/install-helper.sh` installs:
  - [x] `/Library/PrivilegedHelperTools/charge-limit-helperd`
  - [x] `/Library/LaunchDaemons/com.ljzxzxl.ChargeLimiter.Helper.plist`
  - [x] `/var/run/charge-limit-helper.sock`
- [x] Verify helper LaunchDaemon starts after install.
- [x] Verify `.build/release/charge-limit status` talks to the helper socket.
- [x] Verify `.build/release/charge-limit pause` writes `BCLM=15`.
- [x] Verify `.build/release/charge-limit resume` writes `BCLM=100`.
- [ ] Verify `charge-limit-monitor --target 82 --verbose` pauses at 82%.
- [ ] Verify monitor resumes charging after battery drops below target minus hysteresis.
- [x] Add uninstall behavior that restores `BCLM=100` before removing helper.
- [x] Add clearer logs for helper startup, writes, and failures.
- [x] Add a `charge-limit logs` or documented log inspection command.

Acceptance criteria:

- [x] Helper survives launchd restart.
- [x] CLI can query status through the socket.
- [ ] Monitor can pause and resume charging without AlDente running.
- [x] Uninstall leaves the machine in normal charging mode.

## Phase 2: Safety And Compatibility Hardening

Goal: prevent unsupported hardware or bad states from being modified.

- [x] Detect machine model identifier.
- [x] Detect Intel architecture.
- [x] Detect `AppleSMC` availability.
- [x] Detect `AppleSmartBattery` availability.
- [x] Detect whether `BCLM` can be read.
- [x] Add compatibility report to `charge-limit doctor`.
- [x] Refuse writes on unsupported machines by default.
- [x] Add an explicit unsafe override flag for development only.
- [x] Rate-limit repeated SMC writes.
- [x] Track last written value to avoid redundant writes.
- [x] Add whitelist-limited raw SMC read/write development helpers for hardware
  validation.
- [ ] Restore `BCLM=100` on helper shutdown where practical.
- [ ] Add fallback recovery documentation.
- [ ] Add model compatibility table in docs.
- [ ] Decide whether raw SMC development helpers remain, move behind a build
  flag, or are removed before the next public release.

Acceptance criteria:

- [ ] Unsupported machines fail closed with a clear error.
- [ ] Supported machines show a useful compatibility report.
- [ ] Repeated monitor loops do not spam SMC writes.
- [ ] Development-only raw SMC controls are not exposed as production UI.

## Phase 3: Replace MVP Socket With Production IPC

Goal: move from development Unix socket to a production-safe helper interface.

- [x] Research final IPC choice:
  - [x] XPC Mach service from LaunchDaemon.
  - [x] ServiceManagement helper registration.
- [x] Add transport abstraction for swapping Unix socket with XPC.
- [ ] Replace JSON-over-Unix-socket transport with XPC.
- [ ] Validate connecting client code signature.
- [ ] Require matching team identifier / designated requirement.
- [ ] Keep privileged API minimal:
  - [ ] `status`
  - [ ] `setBCLM`
  - [ ] maybe `restoreDefault`
- [ ] Add structured error types for helper responses.
- [ ] Add integration tests around helper request validation.

Acceptance criteria:

- [ ] Unsigned or unrelated clients cannot command the helper.
- [ ] Signed app can query and write through the helper.
- [ ] Helper cannot be used as a broad privileged command runner.

## Phase 4: Menu Bar App

Goal: build the user-facing app.

- [x] Create app target.
- [x] Add menu bar status item.
- [x] Display current battery percentage.
- [x] Display current charge state:
  - [x] Charging
  - [x] Paused
  - [x] On battery
  - [x] Error / unsupported
- [x] Add target percentage control.
- [x] Add enable/disable charge limiting toggle.
- [x] Add helper install/update/remove flow.
- [x] Add launch-at-login toggle.
- [x] Add settings persistence.
- [x] Add safe restore behavior: write `BCLM=100` when disabling limiting or
  uninstalling.
- [x] Add logs / diagnostics export.
- [x] Add first-run warning explaining low-level battery control.
- [x] Remove redundant "Restore Default Charging" menu item.
- [x] Make manual Pause/Resume disable automatic charge limiting after
  confirmation.
- [x] Skip the manual Pause/Resume warning when automatic charge limiting is
  already disabled.
- [x] Retry once after helper write rate limiting so manual Pause/Resume does
  not require a second click.
- [x] Load 1x/2x menu bar PNG representations so the icon is crisp on Retina
  displays.
- [x] Add experimental menu bar discharge-to-target behavior using raw SoC.
- [ ] Add unsupported hardware UI.
- [ ] Add user-facing copy/status for active discharge-to-target mode.

Acceptance criteria:

- [ ] A non-technical user can install helper from the app.
- [ ] A non-technical user can set a target percentage.
- [ ] App shows whether charging is actually paused.
- [ ] App can restore normal charging and uninstall cleanly.
- [ ] App clearly distinguishes automatic limiting, manual pause/resume, and
  discharge-to-target behavior.

## Phase 4.5: Discharge-To-Target Validation

Goal: validate a safe AlDente-like discharge flow without simulating charger
disconnect.

- [x] Verify that with AC attached and `BCLM=15`, the battery can naturally
  discharge on `MacBookPro16,1`.
- [x] Verify macOS UI SoC may lag raw SoC near 100%.
- [x] Change discharge-to-target decisions to prefer `rawStateOfCharge`.
- [x] Keep normal CLI/monitor hysteresis behavior unchanged by default.
- [x] Add menu bar policy mode that writes `BCLM=15` above target and restores
  `BCLM=100` at or below target.
- [x] Probe common adapter-disconnect keys:
  - [x] `CH0B`
  - [x] `CH0C`
  - [x] `CHTE`
  - [x] `CHIE`
  - [x] `CH0I`
  - [x] `CH0J`
- [x] Decide not to pursue simulated charger disconnect on the validated model.
- [ ] Finish long-running real-world validation from 100% toward target 90%.
- [ ] Confirm the app restores `BCLM=100` when raw SoC reaches 90.
- [ ] Record whether the displayed UI SoC catches up after raw SoC reaches
  target.
- [ ] Add logs/status so users can see raw SoC vs UI SoC during discharge.
- [ ] Decide whether discharge-to-target should be always-on, optional, or an
  advanced setting.

Acceptance criteria:

- [ ] Starting above target, the app holds `BCLM=15` while raw SoC is above
  target.
- [ ] At or below target, the app restores `BCLM=100`.
- [ ] The behavior does not continue discharging below target except for normal
  sensor/reporting lag.
- [ ] User can recover normal charging without quitting the app.

## Phase 5: Packaging, Signing, And Notarization

Goal: produce a downloadable release suitable for other users.

- [ ] Enroll/use Apple Developer ID.
- [ ] Configure app signing identity.
- [ ] Configure helper signing identity.
- [ ] Ensure app and helper satisfy ServiceManagement requirements.
- [ ] Add hardened runtime settings.
- [ ] Notarize the app.
- [ ] Staple notarization ticket.
- [x] Build development DMG installer.
- [x] Add development DMG packaging script.
- [x] Add release artifact checksums.
- [x] Document installation and uninstall.
- [x] Verify packaged helper installer uses `com.ljzxzxl.ChargeLimiter.*`
  identifiers.
- [x] Add legacy cleanup for `com.lookslikecode.*` v0.1.0-v0.1.5 installs.

Acceptance criteria:

- [ ] Downloaded app opens without Gatekeeper blocking.
- [ ] Helper install prompts for admin credentials in a standard macOS flow.
- [ ] App and helper are both signed and notarized.

## Phase 6: CI And Release Automation

Goal: make releases reproducible.

- [x] Add GitHub Actions build workflow.
- [x] Add build/release artifact verification in CI.
- [ ] Add lint or formatting check.
- [ ] Add unit tests for policy logic.
- [ ] Add non-hardware tests for protocol and config.
- [x] Add tag-driven release workflow.
- [ ] Add changelog.
- [ ] Add issue templates:
  - [ ] Bug report
  - [ ] Compatibility report
  - [ ] Feature request
- [ ] Add pull request template.

Acceptance criteria:

- [ ] Every PR builds.
- [ ] Releases can be produced from tags.
- [ ] Compatibility reports collect enough machine data to debug safely.

## Phase 7: Broader Hardware Validation

Goal: learn where the `BCLM=100/15` model works.

- [ ] Test additional Intel MacBook models.
- [ ] Record macOS versions.
- [ ] Record whether `BCLM` exists and is writable.
- [ ] Record behavior after sleep/wake.
- [ ] Record behavior after reboot.
- [ ] Record behavior when charger is unplugged/replugged.
- [ ] Record behavior when battery drifts below hysteresis threshold.
- [ ] Record discharge-to-target behavior from above target to target.
- [ ] Record raw SoC vs UI SoC behavior near 100%.
- [ ] Update compatibility matrix.

Acceptance criteria:

- [ ] README clearly lists supported and unsupported models.
- [ ] App refuses unknown models unless user enables an advanced override.

## Phase 8: Product Polish

Goal: make the app understandable and trustworthy.

- [x] Add app icon.
- [x] Add dedicated menu bar PNG icon.
- [x] Localize the menu for Chinese/English system language.
- [ ] Add concise status copy.
- [ ] Add help/about window.
- [ ] Add privacy statement.
- [ ] Add safety FAQ.
- [ ] Add update mechanism or release notification plan.
- [ ] Add localization plan if needed.

Acceptance criteria:

- [ ] A new user understands what the app changes.
- [ ] A new user can recover normal charging without reading source code.

## Always-On Safety Checklist

Before merging any change that can write SMC:

- [ ] The change has a clear rollback path to `BCLM=100`.
- [ ] The change avoids unnecessary repeated writes.
- [ ] The change refuses unsupported hardware by default.
- [ ] The change logs enough context for debugging.
- [ ] The change was tested with `charge-limit doctor`.
- [ ] The change does not leave helper processes or sockets behind after tests.
- [ ] If discharge-to-target is involved, the final state has been checked with
  `charge-limit status` and `smc-read BCLM`.
