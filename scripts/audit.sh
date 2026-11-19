#!/bin/bash
#
# audit.sh: read-only storage audit for a macOS developer machine.
# It only measures and lists. It never deletes, moves or modifies anything.
#
# Usage: audit.sh [--min-mb N]   (default 100: hide anything smaller)
#
set -u
shopt -s nullglob

MIN_MB=100
case "${1:-}" in
  "") ;;
  --min-mb) MIN_MB="${2:?--min-mb needs a number}" ;;
  -h|--help) sed -n '3,7p' "$0"; exit 0 ;;
  *) echo "Usage: $0 [--min-mb N]" >&2; exit 2 ;;
esac
[[ "$MIN_MB" =~ ^[0-9]+$ ]] || { echo "--min-mb must be a whole number" >&2; exit 2; }

L="$HOME/Library"
AS="$L/Application Support"

section() { printf '\n== %s ==\n' "$1"; }

# Print "<size>  <path>" for existing paths >= MIN_MB, largest first.
# -x keeps du on one filesystem, so FSKit mounts (devicefs) are not double counted.
sizes() {
  local p
  for p in "$@"; do
    [[ -e "$p" ]] && du -xsk "$p" 2>/dev/null
  done | sort -rn | awk -F'\t' -v min=$((MIN_MB * 1024)) '
    $1 >= min { if ($1 >= 1048576) printf "%7.1f GB  %s\n", $1/1048576, $2
                else printf "%7.0f MB  %s\n", $1/1024, $2 }'
}

section "FREE SPACE (measure the Data volume, not /)"
df -k /System/Volumes/Data | awk 'NR==2 { printf "Data volume: %.2f GiB free, %.2f GiB used\n", $4/1048576, $3/1048576 }'
diskutil info / 2>/dev/null | grep 'Container Free Space' | sed 's/ (exactly.*//; s/^ *//'
sysctl -n vm.swapusage 2>/dev/null | sed 's/^/Swap: /'

section "APFS VOLUMES IN THE BOOT CONTAINER (all count toward System Data)"
container=$(diskutil info / 2>/dev/null | awk -F': *' '/APFS Container:/ { print $2; exit }')
if [[ -n "$container" ]]; then
  diskutil apfs list "$container" 2>/dev/null | awk -F': *' '
    /APFS Volume Disk \(Role\)/ { role = $2 }
    /Capacity Consumed/ { split($2, a, " "); printf "  %-40s %.1f GB\n", role, a[1] / 1e9 }'
fi

section "SNAPSHOTS (never delete com.apple.os.update-*; Time Machine ones only via tmutil, with consent)"
tmutil listlocalsnapshots / 2>/dev/null | sed 's/^/  /'

section "VIRTUAL MOUNTS INSIDE HOME (not real disk use; excluded from sizes below)"
mount | grep -E 'devicefs|fskit' | grep "$HOME" | sed 's/ (.*//; s/^/  /' || echo "  none"

section "RUNNING APPS (quit the owner before clearing its cache)"
lsappinfo visibleProcessList 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' | tr '_' ' ' | paste -sd, - | sed 's/^/  /'
for p in java gradle dockerd qemu-system-aarch64; do
  pgrep -xq "$p" && echo "  background process running: $p"
done

section "HOME DIRECTORY (top level, >= ${MIN_MB} MB)"
sizes "$L" "$HOME"/.[!.]* "$HOME"/Downloads "$HOME"/Movies "$HOME"/Pictures "$HOME"/Music

section "~/Library BREAKDOWN"
sizes "$L"/* "$L/Caches"/* "$AS"/* "$L/Developer"/* "$L/Developer/Xcode"/* "$L/Developer/Xcode/UserData"/*

section "XCODEBUILDMCP AND XCODE PREVIEWS"
sizes "$L/Developer/XcodeBuildMCP/workspaces"/*/* "$L/Developer/Xcode/UserData/Previews"/*

section "PER-USER TEMP AND CACHE (\$TMPDIR family under /var/folders)"
cache_dir=$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)
if [[ -n "$cache_dir" ]]; then
  root=$(dirname "$cache_dir")
  sizes "$root"/* "$root"/C/* "$root"/X/* "$root"/T/*
fi

section "DEVELOPER TOOL CACHES"
sizes "$HOME/.gradle"/* "$HOME/.gradle/caches"/* "$HOME/.konan"/* "$HOME/.npm"/* \
  "$HOME/.bun/install/cache" "$HOME/.cache"/* "$HOME/.cargo/registry" "$HOME/go/pkg/mod" \
  "$HOME/.cocoapods" "$HOME/.pub-cache" "$HOME/.m2/repository" "$L/pnpm" \
  "$L/Containers/com.docker.docker" "$HOME/.orbstack" "$HOME/.colima"

section "ANDROID"
sizes "$L/Android/sdk"/* "$L/Android/sdk/system-images"/*/* "$HOME/.android/avd"/*.avd
[[ -d "$HOME/.android/avd" ]] && ls "$HOME/.android/avd" | grep '\.avd$' | sed 's/^/  AVD: /'

section "SIMULATOR RUNTIMES (system-level storage, shown as System Data)"
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl runtime list 2>/dev/null | sed 's/^/  /'
  section "SIMULATOR DEVICES (size on disk; clones of a runtime free less than shown)"
  devices=$(xcrun simctl list devices 2>/dev/null)
  sizes "$L/Developer/CoreSimulator/Devices"/*/ | while read -r size unit path; do
    udid=$(basename "$path")
    name=$(grep -F "$udid" <<<"$devices" | sed "s/ ($udid).*//; s/^ *//")
    printf '%7s %s  %s  %s\n' "$size" "$unit" "${name:-not registered}" "$udid"
  done
  unavailable=$(xcrun simctl list devices unavailable 2>/dev/null | grep -c '(')
  echo "  Unavailable devices: $unavailable"
else
  echo "  xcrun not found"
fi

section "TRASH"
if trash_items=$(ls -A "$HOME/.Trash" 2>/dev/null); then
  echo "  $(grep -c . <<<"$trash_items") top-level items, $(du -sh "$HOME/.Trash" 2>/dev/null | cut -f1 | tr -d ' ') total"
else
  echo "  not readable (grant the terminal Full Disk Access to inspect it)"
fi

section "CLAUDE CODE CLI VERSIONS (keep the one ~/.local/bin/claude points to)"
if [[ -d "$HOME/.local/share/claude/versions" ]]; then
  echo "  active: $(basename "$(readlink "$HOME/.local/bin/claude" 2>/dev/null)")"
  sizes "$HOME/.local/share/claude/versions"/*
fi

echo
echo "Audit complete. Nothing was changed."
