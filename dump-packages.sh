#!/usr/bin/env bash
# Refresh Brewfile from what is installed, and print the apps Homebrew does not own.
# ponytail: the manual list is printed, not written — MANUAL_APPS.md has hand notes
# that a dump would clobber. Paste in new lines when something shows up here.
set -euo pipefail
cd "$(dirname "$0")"

# ponytail: --no-vscode because VS Code Settings Sync already syncs extensions.
# Dumping them here only creates a second copy that drifts out of date.
brew bundle dump --file=Brewfile --force --no-vscode
echo "Brewfile: $(grep -c '^brew ' Brewfile) formulae, $(grep -c '^cask ' Brewfile) casks"

echo
echo "MANUAL (in /Applications, not from a cask) — reconcile with MANUAL_APPS.md:"
brew info --json=v2 --installed \
  | jq -r '.casks[].artifacts[]? | select(type=="object") | .app[]? | select(type=="string")' \
  | sort -u > /tmp/.cask_apps.$$
ls /Applications | grep '\.app$' | grep -vxF -f /tmp/.cask_apps.$$ || true
rm -f /tmp/.cask_apps.$$
