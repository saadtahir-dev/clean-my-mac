# clean-my-mac

An agent skill that reclaims disk space on a macOS developer machine without breaking your toolchain.

Developer Macs fill up with build products, simulator data, package caches and app caches. macOS lumps most of it into an opaque "System Data" bar. Generic cleaner apps either miss developer storage or delete things you need. This skill gives a coding agent (Claude Code, or any agent that reads `SKILL.md` folders) a careful, repeatable procedure:

1. **Measure** with a read-only audit script.
2. **Plan**, sorting every target into Safe, Confirm and Never.
3. **Clean** Safe targets with each tool's own command (`simctl`, `brew cleanup`, `npm cache clean`, `gradle --stop`).
4. **Ask** before anything that changes your environment: simulator runtimes, SDKs, emulators, a running app's cache.
5. **Prove** the result with `df` on the Data volume, never with directory sizes alone.

Example result on a 256 GB MacBook Pro used for iOS, Android and web work: **15.6 GiB free to 48.2 GiB free**, with every project, SDK in use, signing asset and chat history intact.

## What it covers

- **Xcode:** DerivedData, SwiftUI preview simulators, simulator devices and runtimes, DeviceSupport, archives, SwiftPM, CocoaPods, Carthage, XcodeBuildMCP.
- **Android:** Gradle caches and daemons, SDK packages, AVDs, Kotlin/Native toolchains, old Android Studio data.
- **Package managers:** npm, pnpm, Yarn, Bun, Playwright, uv, pip, Poetry, conda, Go, Cargo, Dart/Flutter, Ruby, Homebrew, Docker.
- **Electron apps:** Claude, Cursor, VS Code, Slack, Discord, Teams, Figma, Notion. Only caches, old builds and old logs; staged updates get applied by a restart, not deleted.
- **Browsers:** Chrome, Edge and Brave caches and component downloads. Profiles are never touched.
- **System:** per-user temp folders under `/var/folders`, Trash, Time Machine local snapshots, iOS backups, plus an explanation of where "System Data" comes from.

The full catalog, with inspection and cleanup commands per target, is in [`references/targets.md`](references/targets.md).

## Traps it knows about

- `df -h /` shows the sealed system volume, whose usage never changes. Real free space is on `/System/Volumes/Data`.
- `~/Library/Developer/CoreDevice/DeviceFS` can show up as 80+ GB in `du`. It is a virtual FSKit mount of a simulator and uses no disk space of its own.
- Simulator and preview devices are APFS clones. Deleting 15 GB of them can free far less, and APFS may take minutes to report the space.
- `bun pm cache rm` refuses to run outside a project folder.
- `xcrun simctl --set previews delete all` cleans preview simulators, but leaves an orphaned `Simulator%20Devices` folder some setups create.

## What it never touches

Keychains, certificates, provisioning profiles, source code, app databases, browser profiles, Mail, Photos, agent session history and macOS update snapshots. It never uses `sudo rm`, never disables SIP and never installs third-party cleaners. Everything else that is not a regenerable cache waits for your explicit yes.

## Install

Claude Code:

```bash
git clone https://github.com/saadtahir-dev/clean-my-mac ~/.claude/skills/clean-my-mac
```

Then ask: "free up disk space on my Mac", or run `/clean-my-mac`.

For other agents that support skills, clone the folder into that agent's skills directory.

## Run the audit by itself

The audit script is plain Bash, read-only, and useful without an agent:

```bash
~/.claude/skills/clean-my-mac/scripts/audit.sh             # items of 100 MB or more
~/.claude/skills/clean-my-mac/scripts/audit.sh --min-mb 500
```

It takes about a minute on a full disk.

## Layout

```
SKILL.md               rules and workflow the agent follows every run
references/targets.md  per-target catalog: inspect, clean, tier
scripts/audit.sh       read-only storage audit
tests/test-audit.sh    tests: runs the audit against a fake home, checks nothing changed
```

## Contributing

New targets are welcome. Each entry in `references/targets.md` needs the path, how to inspect it, the tool's own cleanup command if one exists, and a tier with the reason. Changes to `audit.sh` must pass `tests/test-audit.sh`. The test fails if the script gains any deleting or modifying command.

## Disclaimer

This skill directs an agent to delete files. It is built to ask first and to touch only regenerable data, but you are responsible for what you approve. Read each confirmation before saying yes. Provided as-is under the MIT license.

This is an independent open-source project. It is not affiliated with or endorsed by MacPaw or its CleanMyMac product.
