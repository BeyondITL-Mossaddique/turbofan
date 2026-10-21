# Changelog

## 1.0.0 — 2026-10-22

First public release.

- Turbo Boost on/off via the TurboFanMSR kext, with Low Power Mode fallback; auto rules for battery,
  temperature and apps; re-applied after sleep.
- Fan control: Auto, Fixed, Linear and Curve modes per fan; Quiet, Balanced, Cool and Full speed presets.
- Profiles (Silent, Balanced, Performance, Max) with automatic switching by apps, external display,
  battery or AC.
- Readings: CPU clock and package power, all SMC temperature sensors, thermal throttling warning.
- Root helper with fan safety: clamped speeds, full speed on lost sensor, auto at 100 °C, auto on
  stop, crash cleanup. `scripts/test-fan-safety.sh`.
- `turbofan` command-line tool.
