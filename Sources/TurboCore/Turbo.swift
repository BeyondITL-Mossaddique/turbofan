// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import Foundation

/// Turbo control. Prefers the TurboFanMSR kext; falls back to Low Power Mode.
public enum Turbo {
    public static let kextID = "com.cloudcoder.TurboFanMSR"
    public static let kextPath = "/Library/Application Support/TurboFan/TurboFanMSR.kext"
    static let sysctlName = "debug.turbofan_turbo"

    public enum Backend: String { case kext = "Kext", lowPower = "Low Power Mode" }

    public struct Status: Equatable {
        public var turboOn: Bool
        public var backend: Backend
        public var lowPowerMode: Bool
    }

    /// Real turbo state from the MSR via the kext sysctl, or nil if the kext is not loaded.
    public static func kextTurboState() -> Bool? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(sysctlName, &value, &size, nil, 0) == 0 else { return nil }
        return value != 0
    }

    public static func lowPowerMode() -> Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    public static var kextInstalled: Bool {
        FileManager.default.fileExists(atPath: kextPath)
    }

    public static func status() -> Status {
        let lpm = lowPowerMode()
        if let on = kextTurboState() {
            return Status(turboOn: on, backend: .kext, lowPowerMode: lpm)
        }
        return Status(turboOn: !lpm, backend: .lowPower, lowPowerMode: lpm)
    }

    public enum Failure: Error, CustomStringConvertible {
        case command(String, String)
        public var description: String {
            switch self {
            case let .command(cmd, out): return "\(cmd) failed: \(out)"
            }
        }
    }

    /// Turn turbo on or off. Returns the backend that did it.
    @discardableResult
    public static func set(on: Bool) throws -> Backend {
        if kextTurboState() != nil {
            try sudo("/usr/sbin/sysctl", "-w", "\(sysctlName)=\(on ? 1 : 0)")
            return .kext
        }
        if kextInstalled {
            if !on { // loading the kext disables turbo
                if (try? sudo("/usr/bin/kmutil", "load", "-b", kextID)) != nil
                    || (try? sudo("/usr/bin/kmutil", "load", "-p", kextPath)) != nil,
                   kextTurboState() != nil {
                    if lowPowerMode() { _ = try? setLowPowerMode(false) }
                    return .kext
                }
            } else if !lowPowerMode() {
                return .kext // kext not loaded and Low Power Mode off: turbo is already on
            }
        }
        try setLowPowerMode(!on)
        return .lowPower
    }

    /// Re-apply a wanted state, e.g. after wake (the MSR can reset on sleep).
    public static func reapply(wantOn: Bool) {
        if let on = kextTurboState(), on != wantOn {
            _ = try? set(on: wantOn)
        }
    }

    public static func setLowPowerMode(_ enabled: Bool) throws {
        try sudo("/usr/bin/pmset", "-a", "lowpowermode", enabled ? "1" : "0")
    }

    /// Runs a command allowed in /etc/sudoers.d/turbofan without a password.
    @discardableResult
    static func sudo(_ args: String...) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n"] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        p.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard p.terminationStatus == 0 else {
            throw Failure.command(args.joined(separator: " "), out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return out
    }
}
