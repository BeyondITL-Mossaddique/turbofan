// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import SwiftUI

enum Brand {
    static let product = "TurboFan"
    static let company = "CloudCoder Limited"
    static let websiteLabel = "cloud-coder.com"
    static let website = URL(string: "https://cloud-coder.com")!
    /// Where "Get Pro" sends people. Point at the TurboFan Pro page once it is live.
    static let proPage = URL(string: "https://cloud-coder.com")!
    static let source = URL(string: "https://github.com/CloudCoderRnD/turbofan")!
    static let license = "GPL-3.0-or-later"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// Which build this is. The open-source build is always Free; a Pro build sets TURBOFAN_PRO.
enum Edition {
    #if TURBOFAN_PRO
    static let isPro = true
    #else
    static let isPro = false
    #endif
    static var name: String { isPro ? "Pro" : "Free" }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text("\(Brand.product) \(Edition.name)").font(.title.bold())
                Text("Version \(Brand.version)").font(.callout).foregroundStyle(.secondary)
                Text("Turbo Boost and fan control for Intel Macs").font(.callout)
            }
            VStack(spacing: 2) {
                Text("Made by \(Brand.company)").font(.callout)
                Link(Brand.websiteLabel, destination: Brand.website).font(.callout.bold())
            }

            if !Edition.isPro {
                Divider()
                VStack(spacing: 6) {
                    Text("You are using the free edition.").font(.callout)
                    Text("TurboFan Pro adds more for power users and supports development.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: Brand.proPage) {
                        Label("Get TurboFan Pro", systemImage: "star.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            HStack {
                Link("Source code", destination: Brand.source)
                Spacer()
                Text("© 2026 \(Brand.company)").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(22)
        .frame(width: 360)
    }
}
