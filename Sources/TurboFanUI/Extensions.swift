// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 CloudCoder Limited

import SwiftUI

/// A tab added to the panel by an edition plug-in.
public struct ExtraTab: Identifiable {
    public let id: String
    public let symbol: String
    public let view: () -> AnyView

    public init(title: String, symbol: String, view: @escaping () -> AnyView) {
        self.id = title
        self.symbol = symbol
        self.view = view
    }
}

/// A button an edition plug-in adds to the panel footer, e.g. "Check for Updates".
public struct ExtraAction: Identifiable {
    public let id: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.id = title
        self.action = action
    }
}

/// Hook for commercial editions of TurboFan. The open-source build leaves `Extensions.edition` nil.
@MainActor
public protocol EditionPlugin: AnyObject {
    /// Shown in the footer and About window, e.g. "Pro" or "Pro trial · 12 days left".
    var editionName: String { get }
    var tabs: [ExtraTab] { get }
    var actions: [ExtraAction] { get }
    /// Extra section for the About window (licence details, for example).
    var aboutSection: AnyView? { get }
}

@MainActor
public enum Extensions {
    public static var edition: EditionPlugin?
}
