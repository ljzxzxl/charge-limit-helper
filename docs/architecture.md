# Architecture

The first development target is a root helper plus user-space monitor.

## Components

`ChargeLimitCore`

- Reads `AppleSmartBattery` from I/O Registry.
- Reads and writes `AppleSMC` key `BCLM`.
- Contains the charge-limit policy.
- Contains the helper request/response protocol.

`charge-limit-helperd`

- Runs as root.
- Listens on `/var/run/charge-limit-helper.sock`.
- Accepts two commands: `status` and `setBCLM`.
- Keeps the privileged surface intentionally tiny.

`charge-limit-monitor`

- Runs as the logged-in user.
- Polls the helper for battery and SMC state.
- Writes `BCLM=100` below the resume threshold.
- Writes `BCLM=15` at or above the target percentage.

`charge-limit`

- Developer CLI for status, pause, resume, and diagnostics.

## Production App Direction

The MVP helper uses a Unix socket restricted to `root:admin` with mode `0660`.
That is acceptable for local development, but not ideal for a distributed app.

For a public app, prefer:

- App bundle installs a LaunchDaemon helper with ServiceManagement.
- Helper exposes an XPC Mach service.
- Helper validates the connecting client's code signature.
- App and helper share a team identifier and designated requirement.

Apple documents `SMAppService` for registering app helpers on macOS 13 and
later. Older privileged helper examples often use `SMJobBless`.

See `docs/production-ipc.md` for the migration plan from the MVP Unix socket to
the final XPC transport.
