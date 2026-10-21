#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 CloudCoder Limited
# Installs TurboFan for the current user. Asks for your password once (sudo).
#
#   scripts/install.sh            app + CLI + kext + password-free switching
#   scripts/install.sh --no-kext  app + CLI only (Low Power Mode backend)
#
# From a source checkout it builds first; from a release zip it uses the included build/ folder.
set -euo pipefail
cd "${0:A:h}/.."

WITH_KEXT=1
[[ "${1:-}" == "--no-kext" ]] && WITH_KEXT=0

USER_NAME=$(id -un)

if [[ -f Package.swift ]]; then
  scripts/build-app.sh
else
  echo "==> Using prebuilt files in build/"
fi
# Downloaded releases carry a quarantine flag that stops ad-hoc signed apps from opening.
xattr -dr com.apple.quarantine build scripts 2>/dev/null || true

echo "==> Installing app to ~/Applications"
mkdir -p ~/Applications
pkill -x TurboFanApp 2>/dev/null || true
rm -rf ~/Applications/TurboFan.app
cp -R build/TurboFan.app ~/Applications/

sudo scripts/install-privileged.sh "$USER_NAME" $WITH_KEXT

open ~/Applications/TurboFan.app
echo
echo "Done. TurboFan is in the menu bar."
if (( WITH_KEXT )); then
  echo "The kext only loads once kext security is lowered — see README.md, 'Enable the kext'."
fi
