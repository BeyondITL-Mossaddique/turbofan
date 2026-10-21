// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import AppKit
import CoreGraphics
import TurboCore

/// What a profile does with Turbo Boost.
enum TurboChoice: String, Codable, CaseIterable, Identifiable {
    case on = "On"
    case off = "Off"
    case rules = "Auto rules"
    var id: String { rawValue }
}

/// One-click combination of a turbo setting and a fan preset.
struct Profile: Codable, Equatable, Identifiable {
    var id: String
    var turbo: TurboChoice
    var fans: String // FanPreset raw value

    var fanPreset: FanPreset { FanPreset(rawValue: fans) ?? .auto }
    var symbol: String {
        switch id {
        case "Silent": return "moon.fill"
        case "Balanced": return "circle.lefthalf.filled"
        case "Performance": return "hare.fill"
        default: return "flame.fill"
        }
    }

    static let defaults: [Profile] = [
        Profile(id: "Silent", turbo: .off, fans: FanPreset.quiet.rawValue),
        Profile(id: "Balanced", turbo: .rules, fans: FanPreset.auto.rawValue),
        Profile(id: "Performance", turbo: .on, fans: FanPreset.cool.rawValue),
        Profile(id: "Max", turbo: .on, fans: FanPreset.full.rawValue),
    ]
}

/// Which profile to pick automatically, by situation. Checked in order: apps, display, power.
struct ProfileRules: Codable, Equatable {
    var enabled = false
    var onBattery = "Silent"
    var onAC = "Balanced"
    var externalDisplay: String? = "Performance"
    var apps: String? = "Silent"
    var appList = "zoom.us, Microsoft Teams, FaceTime"

    var appNames: [String] {
        appList.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
    }
}

enum Situation {
    /// True if any connected display is not the built-in panel.
    static func externalDisplay() -> Bool {
        NSScreen.screens.contains { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) == 0
        }
    }

    /// Name of the first running app from the list (matches app name or bundle ID).
    static func runningApp(from names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        for app in NSWorkspace.shared.runningApplications {
            let name = app.localizedName?.lowercased() ?? ""
            let bundle = app.bundleIdentifier?.lowercased() ?? ""
            if names.contains(name) || names.contains(bundle) { return app.localizedName ?? bundle }
        }
        return nil
    }
}
