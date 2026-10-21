#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 CloudCoder Limited
# Removes TurboFan, unloads the kext (turbo back on) and the sudoers rule.
set -uo pipefail
pkill -x TurboFanApp 2>/dev/null
# Stopping the fan daemon hands all fans back to macOS.
sudo launchctl bootout system/com.cloudcoder.turbofan.helper 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.cloudcoder.turbofan.helper.plist /Library/PrivilegedHelperTools/com.cloudcoder.turbofan.helper
sudo kmutil unload -b com.cloudcoder.TurboFanMSR 2>/dev/null
sudo rm -rf "/Library/Application Support/TurboFan" /etc/sudoers.d/turbofan /usr/local/bin/turbofan
rm -rf ~/Applications/TurboFan.app
echo "Removed. Low Power Mode was left as it is: sudo pmset -a lowpowermode 0 to turn it off."
