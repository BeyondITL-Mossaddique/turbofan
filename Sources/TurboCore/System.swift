// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import Foundation
import IOKit.ps
import IOKit.pwr_mgt

/// CPU load, power source and other cheap system readings.
public final class CPULoad {
    private var previous: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []

    public init() { _ = sample() }

    /// Average CPU usage (0...1) across all cores since the previous call.
    public func sample() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }

        var current: [(UInt32, UInt32, UInt32, UInt32)] = []
        for i in 0..<Int(count) {
            let base = Int(CPU_STATE_MAX) * i
            current.append((UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                            UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                            UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                            UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])))
        }
        defer { previous = current.map { (user: $0.0, system: $0.1, idle: $0.2, nice: $0.3) } }
        guard previous.count == current.count else { return 0 }

        var busy: UInt64 = 0, total: UInt64 = 0
        for (now, old) in zip(current, previous) {
            let u = UInt64(now.0 &- old.user), s = UInt64(now.1 &- old.system)
            let i = UInt64(now.2 &- old.idle), n = UInt64(now.3 &- old.nice)
            busy += u + s + n
            total += u + s + n + i
        }
        return total == 0 ? 0 : Double(busy) / Double(total)
    }
}

public enum Power {
    /// True when running on battery.
    public static func onBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        return type == kIOPSBatteryPowerValue
    }

    /// Battery charge percent, if there is a battery.
    public static func batteryPercent() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            if let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
               let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 {
                return cur * 100 / max
            }
        }
        return nil
    }
}

/// One reading for the charts.
public struct Sample: Identifiable {
    public let id = UUID()
    public let date: Date
    public let temperature: Double?
    public let fan: Double?
    public let load: Double
    public let turboOn: Bool
    public let watts: Double?
    public let mhz: Double?

    public init(date: Date, temperature: Double?, fan: Double?, load: Double, turboOn: Bool,
                watts: Double? = nil, mhz: Double? = nil) {
        self.date = date
        self.temperature = temperature
        self.fan = fan
        self.load = load
        self.turboOn = turboOn
        self.watts = watts
        self.mhz = mhz
    }
}

/// macOS thermal throttling state (same data as `pmset -g therm`), no root needed.
public enum Thermal {
    public struct State: Equatable {
        /// Percent of full speed macOS currently allows (100 = no throttling).
        public var speedLimit: Int
        public var schedulerLimit: Int
        public var throttled: Bool { speedLimit < 100 || schedulerLimit < 100 }
    }

    public static func read() -> State {
        var dict: Unmanaged<CFDictionary>?
        guard IOPMCopyCPUPowerStatus(&dict) == kIOReturnSuccess,
              let status = dict?.takeRetainedValue() as? [String: Any] else {
            return State(speedLimit: 100, schedulerLimit: 100)
        }
        let speed = status[kIOPMCPUPowerLimitProcessorSpeedKey] as? Int ?? 100
        let sched = status[kIOPMCPUPowerLimitSchedulerTimeKey] as? Int ?? 100
        return State(speedLimit: speed, schedulerLimit: sched)
    }
}
