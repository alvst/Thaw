//
//  UserNotificationIdentifier.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

/// An identifier for a user notification.
enum UserNotificationIdentifier: String {
    case updateCheck = "UpdateCheck"
    case triggerFired = "TriggerFired"
    /// An automatic move (a trigger, the saved layout, a relocation) failed
    /// for good; opening the notification reveals the saved diagnostic report.
    case moveFailed = "MoveFailed"
}
