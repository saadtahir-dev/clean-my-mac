# Cleanup targets

Each entry: what it is, how to inspect it, how to clean it, and its tier (Safe, Confirm, Never) as defined in `SKILL.md`. Paths use `~` for the home folder. Before any delete, list the folder and check open handles with `lsof +D <dir> | wc -l`.

## Xcode and simulators

- **DerivedData** `~/Library/Developer/Xcode/DerivedData`. Build products, indexes, module caches. Inspect: `du -sh ~/Library/Developer/Xcode/DerivedData/*`. Clean: delete the folder's contents. **Safe** if no build is running (`pgrep -x xcodebuild`). The next build is a full rebuild.
- **SwiftUI preview simulators** `~/Library/Developer/Xcode/UserData/Previews/Simulator Devices`. Clean: `xcrun simctl --set previews delete all`. **Safe.** A sibling folder named `Simulator%20Devices` is an orphaned, URL-encoded duplicate. `simctl` will not touch it. If its device folders have no `device.plist` and no open handles, delete it.
- **Simulator devices** `~/Library/Developer/CoreSimulator/Devices/<UDID>`. Map a UDID to its name with `xcrun simctl list devices`. Clean: `xcrun simctl delete unavailable` is **Safe**. `xcrun simctl erase <UDID>` (wipes apps and data, keeps the device) and `xcrun simctl delete <UDID>` are **Confirm**. Never erase a booted device, or the one named in a project's run configuration, without asking.
- **Simulator runtimes** live in `/Library/Developer/CoreSimulator` (system level, shown as System Data). Inspect: `xcrun simctl runtime list -j` gives `sizeBytes` and `lastUsedAt` per runtime. Cross-check which devices use each runtime with `xcrun simctl list devices`. Device-specific builds (identifier like `iOS-27-2-iPhone19-4`) back only one device model. Clean: `xcrun simctl runtime delete <ID>`. **Confirm.** `--unusable` (runtimes the installed Xcode cannot run) is **Safe**. Preview `--outdated` or `--notUsedSinceDays <n>` with `--dry-run` first. Keep the runtime that matches the project's minimum deployment target. `delete` can print a "scan-and-mount" warning and still succeed. Verify with `xcrun simctl runtime list`.
- **CoreDevice DeviceFS** `~/Library/Developer/CoreDevice/DeviceFS`. An FSKit `devicefs` virtual mount of a simulator's filesystem (`mount | grep devicefs`). It uses no disk space of its own. **Never** delete.
- **iOS DeviceSupport** `~/Library/Developer/Xcode/*DeviceSupport/<version>`. Debug symbols copied from physical devices. Clean: delete OS versions no connected device still runs (`xcrun devicectl list devices`). **Safe** for old versions. Xcode copies them again on next connect.
- **Archives** `~/Library/Developer/Xcode/Archives`. Hold the dSYMs for shipped builds, needed to symbolicate crash reports. **Confirm**, per archive. Suggest keeping anything that matches a version still in users' hands.
- **XcodeBuildMCP** `~/Library/Developer/XcodeBuildMCP/workspaces/<name>`. Delete only `DerivedData` and `test-products` inside each workspace. **Safe.** Keep `state`, `logs` and anything else.
- **DocumentationCache, CodingAssistant** `~/Library/Developer/Xcode/`. Small and slow to rebuild. Keep, unless the user asks.
- **Old Xcode installs** `/Applications/Xcode*.app`. **Confirm.** Move to Trash only with consent, and never the one `xcode-select -p` points to.
- **SwiftPM** `~/Library/Caches/org.swift.swiftpm`. Clean: `swift package purge-cache` from any package folder, or delete the folder. **Safe.**
- **CocoaPods** `~/Library/Caches/CocoaPods`. Clean: `pod cache clean --all`. **Safe.**
- **Carthage** `~/Library/Caches/org.carthage.CarthageKit`. **Safe.**

## Android, Gradle, Kotlin

- **Gradle daemons.** Check with `pgrep -x java`. Stop them with `gradle --stop` or `./gradlew --stop` in a project before touching caches.
- **Gradle build cache** `~/.gradle/caches/build-cache-1`. **Safe.**
- **Gradle per-version caches** `~/.gradle/caches/<gradle-version>`. Transforms and Kotlin DSL accessors. Old versions no project wrapper uses are **Safe**. The current version is **Confirm** (it regenerates, but the next build is slow).
- **Gradle dependencies** `~/.gradle/caches/modules-2`. Downloaded jars. **Confirm.** The next build downloads them again.
- **Gradle distributions** `~/.gradle/wrapper/dists/<version>`. Versions not referenced by any project's `gradle/wrapper/gradle-wrapper.properties` are **Safe**.
- **Gradle daemon logs** `~/.gradle/daemon/<version>/*.log`. **Safe.**
- **Android SDK** `~/Library/Android/sdk`. Inspect: `sdkmanager --list_installed` (in `cmdline-tools/latest/bin`). Clean: `sdkmanager --uninstall "<package>"`. **Confirm.** Never remove the build-tools, platform or system image a project's `compileSdk`/`targetSdk` or an existing AVD needs.
- **AVDs** `~/.android/avd`. Inspect: `emulator -list-avds`. Clean: `avdmanager delete avd -n <name>`, or Android Studio Device Manager. **Confirm.** A lighter option: delete `<name>.avd/snapshots` (Quick Boot state; costs one cold boot).
- **Old Android Studio data** `~/Library/Application Support/Google/AndroidStudio<version>`, `~/Library/Caches/Google/AndroidStudio<version>`, `~/Library/Logs/Google/AndroidStudio<version>`. Versions that no longer match the installed app are **Safe**.
- **Kotlin/Native** `~/.konan/kotlin-native-prebuilt-<os>-<version>` and `~/.konan/dependencies`. Toolchains, not just cache. Versions that match no project's Kotlin plugin (check `gradle/libs.versions.toml`) are **Confirm**. Keep the version in use.

## JavaScript and other languages

- **npm** `~/.npm/_cacache`. Clean: `npm cache clean --force`. **Safe.** `~/.npm/_npx` holds packages `npx` runs, often MCP servers. **Confirm.**
- **pnpm** `~/Library/pnpm/store`. Clean: `pnpm store prune`. **Safe.**
- **Yarn.** Clean: `yarn cache clean` (classic) or `yarn cache clean --all` (Berry). **Safe.**
- **Bun** `~/.bun/install/cache`. `bun pm cache rm` refuses to run outside a project ("No package.json was found"). Run it from a temporary folder holding `{}` as `package.json`, then delete that folder. **Safe.**
- **Playwright browsers** `~/Library/Caches/ms-playwright`. Browser tools and agents may depend on them. **Confirm.** Reinstall with `npx playwright install`.
- **node-gyp** `~/Library/Caches/node-gyp`. **Safe.**
- **Python:** `uv cache clean`, `pip cache purge`, `poetry cache clear --all pypi`, `conda clean --all`. **Safe** (conda: **Confirm**).
- **Go:** `go clean -cache` is **Safe**. `go clean -modcache` is **Confirm**.
- **Rust** `~/.cargo/registry/cache`. Downloaded `.crate` files. **Safe.** Project `target/` folders live in projects: **Confirm**, per project.
- **Dart and Flutter** `~/.pub-cache`. Clean: `flutter pub cache clean` or `dart pub cache clean`. **Confirm.**
- **Ruby:** extra versions under `~/.rbenv/versions` or `~/.rvm` are **Confirm**. `gem cleanup` is **Confirm**.
- **Homebrew.** Clean: `brew cleanup --prune=all`. **Safe.** `brew autoremove` is **Confirm** (removes formulae nothing depends on).
- **Docker, OrbStack, Colima.** Inspect: `docker system df`. `docker builder prune` is **Confirm**. `docker image prune -a` is **Confirm**. `docker volume prune` deletes database data: **Confirm**, with the volume names shown. Docker Desktop's `Docker.raw` shrinks only after a prune.

## Electron apps (Claude, Cursor, VS Code, Slack, Discord, Teams, Figma, Notion)

App data lives in `~/Library/Application Support/<App>`.
- **Safe when the app is quit:** `Cache`, `Code Cache`, `GPUCache`, `DawnWebGPUCache`, `DawnGraphiteCache`, `Shared Dictionary`, `CachedExtensionVSIXs` (VS Code). Old session folders in `logs` (keep the newest).
- **Running app:** **Confirm**. The app rebuilds the cache, but open windows may misbehave until restarted.
- **CachedData** (VS Code and Cursor): one folder per app build. Keep the folder matching `"commit"` in `/Applications/<App>.app/Contents/Resources/app/product.json`. Delete the others. **Safe.**
- **Staged updates** `~/Library/Caches/com.<id>.ShipIt/update.*`. A downloaded update waiting to install. Don't delete it. Tell the user to restart the app, which installs the update and clears the folder.
- **Never:** `User/` (settings, `state.vscdb` chat history, `workspaceStorage`), `IndexedDB`, `Local Storage`, `Session Storage`, `Partitions`, `Cookies`, extensions (`~/.cursor/extensions`, `~/.vscode/extensions`).
- **Cursor agent CLI** `~/Library/Application Support/Cursor/User/globalStorage/anysphere.cursor-agent-worker/agent-cli/.local/share/cursor-agent/versions/<v>`. Keep the version `.local/bin/cursor-agent` links to, and any version with open handles. Others are **Safe**.
- **Claude desktop:** `Cache`, `Code Cache`, `GPUCache` are **Safe** when the app is quit. `vm_bundles` is **Confirm** (downloads again). `claude-code`, `claude-code-vm`, `local-agent-mode-sessions` and `IndexedDB` are **Never**.

## Agent CLIs

- **Claude Code versions** `~/.local/share/claude/versions/<v>`. Keep the version `~/.local/bin/claude` links to, and any version a running session uses (`lsof <version-file>`). Others are **Confirm**: each is about 300 MB, and the updater reinstalls as needed.
- **Claude Code data** `~/.claude`. `projects/` is session history: **Never**. `plugins/` and `skills/` are installed tooling: **Never**.

## Browsers

- **Chrome cache** `~/Library/Caches/Google/Chrome/<Profile>/{Cache,Code Cache}`. Delete only those two folders per profile. **Safe** when Chrome is quit, **Confirm** while it runs. Edge (`~/Library/Caches/Microsoft Edge`) and Brave (`~/Library/Caches/BraveSoftware`) use the same layout.
- **Chrome components** `~/Library/Application Support/Google/Chrome/{optimization_guide_model_store,component_crx_cache,GraphiteDawnCache,WasmTtsEngine}`. Downloaded on demand. **Safe.**
- **GoogleUpdater** `~/Library/Application Support/Google/GoogleUpdater/crx_cache`. Update download cache. **Safe.**
- **Chrome code-sign clone** `<per-user folder>/X/com.google.Chrome.code_sign_clone`. An APFS clone of the running Chrome app. It costs almost no physical space, and Chrome removes it on quit. **Never** delete it while Chrome runs.
- **Profiles** `~/Library/Application Support/Google/Chrome/{Default,Profile N}`. **Never.**
- **Safari** caches are protected by macOS privacy controls. Leave them.

## System and miscellaneous

- **Per-user temp and cache** `/var/folders/<xx>/<id>/`: `C` (cache, `getconf DARWIN_USER_CACHE_DIR`), `T` (temp, `$TMPDIR`), `X` (code-sign clones). `C/clang/ModuleCache` is **Safe** when no compiler is running. Leave `C/com.apple.*`. Never empty `T` wholesale, because running apps use it. A reboot clears stale temp files.
- **Updater downloads** like `~/Library/Caches/notion-updater`: **Safe** when the app isn't installed, or the downloaded version is already installed.
- **Logs** `~/Library/Logs`: `DiagnosticReports` older than 30 days and `CoreSimulator` logs are **Safe**.
- **Trash** `~/.Trash`. **Confirm.** Show the item count first. Reading it may need Full Disk Access for the terminal.
- **iOS device backups** `~/Library/Application Support/MobileSync/Backup`. **Confirm**, and only through Finder (device, Manage Backups). They may be the only copy of a phone's data.
- **Mail attachments** `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`. **Confirm.**
- **macOS installers** `/Applications/Install macOS*.app`. **Confirm.**
- **Large downloads.** Find with `find ~/Downloads -size +500M -mtime +30`. **Confirm**, per file.
- **Time Machine local snapshots** (`com.apple.TimeMachine.*`). Inspect: `tmutil listlocalsnapshots /`. Clean: `tmutil thinlocalsnapshots / 999999999999 4`. **Confirm.** macOS also thins them on its own under disk pressure.
- **OS update snapshot** `com.apple.os.update-*`. The base snapshot of the sealed system volume. **Never.** It does not consume Data-volume space.
