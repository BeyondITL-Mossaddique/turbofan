// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import SwiftUI

enum Brand {
    static let product = "TurboFan"
    static let company = "CloudCoder Limited"
    static let website = URL(string: "https://cloud-coder.com")!
    static let source = URL(string: "https://github.com/CloudCoderRnD/turbofan")!
    static let license = "GPL-3.0-or-later"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

struct AboutView: View {
    private struct Credit: Identifiable {
        let id = UUID()
        let who: String
        let what: String
        let note: String
        let url: URL
    }

    private let credits = [
        Credit(who: "Rubén García Pérez", what: "Turbo Boost Switcher",
               note: "Showed that one switch could keep a hot Intel Mac cool and quiet, and gave it away free and open source.",
               url: URL(string: "https://github.com/rugarciap/Turbo-Boost-Switcher")!),
        Credit(who: "CrystalIdea Software", what: "Macs Fan Control",
               note: "The fan tool that set the bar for sensor-based fan control on the Mac.",
               url: URL(string: "https://crystalidea.com/macs-fan-control")!),
        Credit(who: "Hendrik Holtmann", what: "smcFanControl",
               note: "Early open-source SMC work that taught a generation how Mac fans talk.",
               url: URL(string: "https://github.com/hholtmann/smcFanControl")!),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text(Brand.product).font(.title.bold())
                Text("Version \(Brand.version)").font(.callout).foregroundStyle(.secondary)
                Text("Turbo Boost and fan control for Intel Macs").font(.callout)
            }
            HStack(spacing: 4) {
                Text("Made by")
                Link(Brand.company, destination: Brand.website)
            }
            .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("With thanks").font(.headline)
                Text("TurboFan stands on the shoulders of people who made life easier for many Mac users.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(credits) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(c.who).bold()
                            Text("·").foregroundStyle(.secondary)
                            Link(c.what, destination: c.url)
                        }
                        Text(c.note).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("TurboFan is an independent project and contains no code from these apps.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                Link("Source code", destination: Brand.source)
                Spacer()
                Text("Free software · \(Brand.license)").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(22)
        .frame(width: 400)
    }
}
