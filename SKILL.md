---
name: clean-my-mac
description: Audit and reclaim disk space on a macOS developer machine (Xcode, simulators, Android and Gradle, Node, Bun, Python, Homebrew, Docker, Electron apps, browsers, and "System Data"). Measures first, clears regenerable caches with each tool's own command, asks before anything that changes the dev environment, and proves recovery with df. Use for: clean my mac, free up disk space, disk is full, System Data is huge, reclaim storage, mac cleanup.
---

# clean-my-mac

Measure, then clear only what regenerates, then prove it with `df`. A smaller disk bill is never worth a broken toolchain.

## Hard rules

- Never delete: Keychains, certificates, `~/Library/MobileDevice/Provisioning Profiles`, source and project folders, app databases (`state.vscdb`, `IndexedDB`, `Local Storage`, `Session Storage`, `Cookies`, `Login Data`), browser profile folders, `~/Library/Mail`, Photos libraries, `~/.claude/projects` and other agent session history, APFS `com.apple.os.update-*` snapshots, anything under `/System`.
- No `sudo rm`, no disabling SIP, no third-party cleaner apps, no cleanup script files. Run each command directly so the user sees it.
- Look before you delete: list the folder's contents and run `lsof +D <dir> | wc -l` for open handles. Never `rm -rf` a glob over a parent you have not listed.
- Prefer the tool's own cleanup command (`simctl`, `brew cleanup`, `npm cache clean`, `gradle --stop`) over `rm`.
- Check running apps right before deleting an app's cache (`lsappinfo visibleProcessList`). State changes during a session.
- List processes by name or pid only (`pgrep -x`, `pgrep -l`). Full arguments (`ps aux`, `pgrep -f`) leak tokens from environment and flags.
- Keep paths, usernames and sizes on the machine. Nothing goes to outside services.

## Workflow

1. **Baseline.** Run `scripts/audit.sh` (read-only, about a minute). Record the Data-volume free space it prints. That number is the baseline for every later claim.
2. **Drill down.** For each item of 500 MB or more, read its entry in `references/targets.md` and run that entry's inspection command. An item with no entry: list it, find its owner, and treat it as Confirm until you know it regenerates.
3. **Plan.** Show one table (Target, Size, Action, Risk, Expected recovery) split into three tiers:
   - **Safe:** regenerable cache whose owner is not running, or one with a native clean command. Cost is only a re-download or a rebuild.
   - **Confirm:** removes a tool version, runtime, SDK, emulator, simulator or its data, a cache of a running app, Trash, Docker data, or anything over 5 GB.
   - **Never:** the hard-rule list, plus anything still unidentified.
4. **Execute Safe items** in small batches. After each batch, re-measure the targets with `du -sh` and the volume with `df -k /System/Volumes/Data`.
5. **Ask about Confirm items** with AskUserQuestion: multi-select, at most 4 options per question, each with its size, what is lost and how to get it back. If the user dismisses the question by accident, ask again. Never treat silence as yes.
6. **Verify and report** (format below).

## Measuring traps

- `/` is the sealed system volume and its "Used" figure never changes. Measure `/System/Volumes/Data`.
- APFS frees space asynchronously. After deleting simulators or runtimes, `df` can lag by minutes. Re-measure before concluding nothing was freed.
- Simulator devices, preview devices and Chrome's `code_sign_clone` are APFS clones that share blocks. Their logical size can be far above the physical gain. Report both.
- Free space also moves with swap (the VM volume) and with what other apps write. Compare against the baseline, and cross-check with `diskutil info / | grep 'Container Free'`.
- `~/Library/Developer/CoreDevice/DeviceFS` is an FSKit `devicefs` mount: a virtual view of a simulator, not disk use. Plain `du` counts it twice. Use `du -x` and never delete inside it.
- macOS "System Data" lumps together simulator runtimes (`/Library/Developer/CoreSimulator`, outside home), the Preboot, VM and Recovery volumes, snapshots, and most of `~/Library`. Explain it with the audit's APFS volume list.

## Final report

- Free space at baseline and at the end, both from `df -k /System/Volumes/Data`. Claim recovery only from these two numbers.
- Items removed, with logical size each. Say where physical gain differs, and why.
- Items kept, with the reason for each.
- Items needing the user (Confirm items declined or deferred, apps to restart).
- What will re-download or rebuild on next use.
