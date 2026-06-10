//
//  AXHelpers.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@preconcurrency import AXSwift
import Cocoa

enum AXHelpers {
    private static let queue = DispatchQueue.targetingGlobal(
        label: "AXHelpers.queue",
        qos: .userInteractive,
        attributes: .concurrent
    )

    @discardableResult
    static func isProcessTrusted(prompt: Bool = false) -> Bool {
        queue.sync { checkIsProcessTrusted(prompt: prompt) }
    }

    static func element(at point: CGPoint) -> UIElement? {
        queue.sync { try? systemWideElement.elementAtPosition(Float(point.x), Float(point.y)) }
    }

    static func application(for runningApp: NSRunningApplication) -> Application? {
        queue.sync { Application(runningApp) }
    }

    static func extrasMenuBar(for app: Application) -> UIElement? {
        queue.sync { try? app.attribute(.extrasMenuBar) }
    }

    static func children(for element: UIElement) -> [UIElement] {
        queue.sync { try? element.arrayAttribute(.children) } ?? []
    }

    static func isEnabled(_ element: UIElement) -> Bool {
        queue.sync { try? element.attribute(.enabled) } ?? false
    }

    /// The raw AXEnabled attribute, or nil when the element does not expose it.
    /// isEnabled collapses a missing attribute to false, so it cannot tell an
    /// explicitly disabled element from one that simply does not publish the
    /// attribute. Callers that must keep that distinction use this: source-PID
    /// matching treats absent as enabled, and the unresolved-item diagnostics
    /// report it verbatim.
    static func enabledAttribute(_ element: UIElement) -> Bool? {
        queue.sync { try? element.attribute(.enabled) }
    }

    static func frame(for element: UIElement) -> CGRect? {
        queue.sync { try? element.attribute(.frame) }
    }

    static func role(for element: UIElement) -> Role? {
        queue.sync { try? element.role() }
    }

    /// The element's `AXTitle`, when present. On macOS 27 most menu bar
    /// item elements leave this empty, so callers fall back to ``identifier``.
    static func title(for element: UIElement) -> String? {
        queue.sync { try? element.attribute(.title) }
    }

    /// The element's `AXIdentifier`, when present. Thaw sets a stable
    /// identifier on its control-item buttons so they can be recognized in
    /// the macOS 27 Accessibility-based enumeration.
    static func identifier(for element: UIElement) -> String? {
        queue.sync { try? element.attribute(.identifier) }
    }

    /// The element's `AXSubrole`, when present. Used to distinguish menu bar
    /// status items from incidental children (popovers, menus) on macOS 27.
    static func subrole(for element: UIElement) -> String? {
        queue.sync { try? element.attribute(.subrole) }
    }

    static func pid(for element: UIElement) -> pid_t? {
        queue.sync {
            var pid: pid_t = 0
            let result = AXUIElementGetPid(element.element, &pid)
            return result == .success ? pid : nil
        }
    }

    /// Performs the press action on the given element, returning whether it
    /// succeeded. Used to open the menus of Electron/Chromium tray items, which
    /// ignore synthetic mouse clicks.
    @discardableResult
    static func press(_ element: UIElement) -> Bool {
        queue.sync {
            do {
                try element.performAction(.press)
                return true
            } catch {
                return false
            }
        }
    }
}
