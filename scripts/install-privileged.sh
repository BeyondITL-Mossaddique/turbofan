#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 CloudCoder Limited
# Root part of the install. Run as root: install-privileged.sh <user> <with_kext 0|1>
# Called by install.sh via sudo, or via a macOS admin password dialog.
set -euo pipefail
cd "${0:A:h}/.."

USER_NAME=$1
WITH_KEXT=${2:-1}
KEXT_ID=com.cloudcoder.TurboFanMSR
KEXT_DIR="/Library/Application Support/TurboFan"
KEXT_DEST="$KEXT_DIR/TurboFanMSR.kext"
FAND_LABEL=com.cloudcoder.turbofan.helper

[[ $EUID -eq 0 ]] || { echo "must run as root"; exit 1; }

# launchd stops services asynchronously; wait, and retry the start, or bootstrap fails with error 5.
stop_service() {
  launchctl bootout "system/$1" 2>/dev/null || true
  for _ in {1..20}; do launchctl print "system/$1" >/dev/null 2>&1 || return 0; sleep 0.5; done
}
start_service() {
  for _ in {1..5}; do launchctl bootstrap system "$1" 2>/dev/null && return 0; sleep 1; done
  launchctl bootstrap system "$1"
}
[[ "$USER_NAME" =~ ^[a-z_][a-z0-9_.-]*$ ]] || { echo "bad user name"; exit 1; }

# Pre-release builds were called TurboSwitch; remove them so two helpers never fight over the fans.
if [[ -e /Library/LaunchDaemons/com.cloudcoder.turboswitch.fand.plist || -e /etc/sudoers.d/turboswitch ]]; then
  echo "==> Removing old TurboSwitch install"
  stop_service com.cloudcoder.turboswitch.fand
  kmutil unload -b com.cloudcoder.TurboSwitchMSR 2>/dev/null || true
  rm -f /Library/LaunchDaemons/com.cloudcoder.turboswitch.fand.plist /Library/PrivilegedHelperTools/com.cloudcoder.turboswitch.fand
  rm -rf "/Library/Application Support/TurboSwitch" /etc/sudoers.d/turboswitch /usr/local/bin/turbo /var/log/turboswitch-fand.log
  rm -rf "/Users/$USER_NAME/Applications/TurboSwitch.app"
fi

echo "==> Installing CLI to /usr/local/bin/turbofan"
mkdir -p /usr/local/bin
install -m 755 build/turbofan /usr/local/bin/turbofan

if (( WITH_KEXT )); then
  echo "==> Installing kext to $KEXT_DEST (root:wheel)"
  mkdir -p "$KEXT_DIR"
  rm -rf "$KEXT_DEST"
  cp -R build/TurboFanMSR.kext "$KEXT_DEST"
  chown -R root:wheel "$KEXT_DEST"
  chmod -R go-w "$KEXT_DEST"
fi

echo "==> Installing fan daemon ($FAND_LABEL)"
USER_UID=$(id -u "$USER_NAME")
FAND_BIN=/Library/PrivilegedHelperTools/$FAND_LABEL
FAND_PLIST=/Library/LaunchDaemons/$FAND_LABEL.plist
stop_service $FAND_LABEL
mkdir -p /Library/PrivilegedHelperTools
install -m 755 -o root -g wheel build/turbofand "$FAND_BIN"
cat > "$FAND_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$FAND_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$FAND_BIN</string>
		<string>--allow-uid</string>
		<string>$USER_UID</string>
	</array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>StandardOutPath</key><string>/var/log/turbofan.log</string>
	<key>StandardErrorPath</key><string>/var/log/turbofan.log</string>
</dict>
</plist>
PLIST
chown root:wheel "$FAND_PLIST"
chmod 644 "$FAND_PLIST"
start_service "$FAND_PLIST"

echo "==> Allowing password-free switching (/etc/sudoers.d/turbofan)"
KEXT_ESC=${KEXT_DEST// /\\ }
TMP=$(mktemp)
cat > "$TMP" <<EOF
# TurboFan: exact commands only, no wildcards.
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1
$USER_NAME ALL=(root) NOPASSWD: /usr/sbin/sysctl -w debug.turbofan_turbo=0, /usr/sbin/sysctl -w debug.turbofan_turbo=1
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/kmutil load -b $KEXT_ID, /usr/bin/kmutil load -p $KEXT_ESC, /usr/bin/kmutil unload -b $KEXT_ID
EOF
visudo -cf "$TMP"
install -m 440 -o root -g wheel "$TMP" /etc/sudoers.d/turbofan
rm -f "$TMP"
echo "==> Root install done"
