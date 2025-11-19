#!/usr/bin/env bash

# Remove root user check (containers run as root)
if grep -q "process.getuid() === 0" vendor/adevtool/bin/run
then
  sed -i '/process.getuid() === 0/,/^}$/d' vendor/adevtool/bin/run
  echo "INFO: Applied adevtool root check removal patch"
fi

# Skip device nodes in copy.ts (can't copy block/char devices in containers)
if grep -q "isSymbolicLink()" vendor/adevtool/src/blobs/copy.ts
then
  sed -i 's/if (stat.isSymbolicLink()) {/if (stat.isSymbolicLink() || stat.isBlockDevice() || stat.isCharacterDevice()) {/' vendor/adevtool/src/blobs/copy.ts
  echo "INFO: Applied adevtool device node skip patch"
fi

# Fix TTY function issues in containers (getWindowSize, moveCursor, clearScreenDown)
if grep -q "process.stdout.getWindowSize()" vendor/adevtool/src/util/log.ts
then
  # Fix getWindowSize
  sed -i 's/let width = process.stdout.getWindowSize()\[0\]/let width = (process.stdout.getWindowSize ? process.stdout.getWindowSize()[0] : 80)/' vendor/adevtool/src/util/log.ts
  # Disable cursor movement in containers - stub out clearStatusLines function body
  sed -i '/^function clearStatusLines() {$/,/^}$/ {
    /^function clearStatusLines() {$/n
    /^}$/!c\
if (numStatusLines == 0 || isClearPending) return\
numStatusLines = 0\
currentStatus = null
}' vendor/adevtool/src/util/log.ts
  echo "INFO: Applied adevtool TTY compatibility patch"
fi

# Fix vendor-skel copy race condition (parallel devices creating shared parent dir)
if grep -q "errorOnExist: true" vendor/adevtool/src/commands/generate-all.ts
then
  sed -i 's/errorOnExist: true/errorOnExist: false/' vendor/adevtool/src/commands/generate-all.ts
  sed -i 's/force: false/force: true/' vendor/adevtool/src/commands/generate-all.ts
  echo "INFO: Applied adevtool vendor-skel copy race fix"
fi

# Allow nsjail stderr warning in dependency builds (nsjail doesn't work in containers)
if grep -q "return line.endsWith('setpriority(5): Permission denied')" vendor/adevtool/src/config/paths.ts
then
  sed -i "s/return line.endsWith('setpriority(5): Permission denied')/return line.endsWith('setpriority(5): Permission denied') || line.includes('nsjail')/" vendor/adevtool/src/config/paths.ts
  echo "INFO: Applied adevtool nsjail stderr patch"
fi

