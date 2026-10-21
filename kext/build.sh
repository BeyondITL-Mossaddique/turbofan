#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 CloudCoder Limited
# Builds build/TurboFanMSR.kext (x86_64, ad-hoc signed).
set -euo pipefail
cd "${0:A:h}"
SDK=$(xcrun --show-sdk-path)
OUT=../build/TurboFanMSR.kext
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"

xcrun clang -arch x86_64 -mmacosx-version-min=11.0 -isysroot "$SDK" \
  -mkernel -nostdlib -fno-builtin -fno-common -fno-stack-protector \
  -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT \
  -I"$SDK/System/Library/Frameworks/Kernel.framework/Headers" \
  -O2 -Wall -Wextra -Wno-unused-parameter \
  -Xlinker -kext -Xlinker -export_dynamic \
  -L"$SDK/usr/lib" -lkmod -lcc_kext \
  TurboFanMSR.c -o "$OUT/Contents/MacOS/TurboFanMSR"

cp Info.plist "$OUT/Contents/Info.plist"
codesign --force --sign - "$OUT"
echo "built $OUT"
