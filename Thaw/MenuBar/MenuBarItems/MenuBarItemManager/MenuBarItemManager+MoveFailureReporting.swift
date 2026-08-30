//
//  MenuBarItemManager+MoveFailureReporting.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa

/// Telling the user about automatic moves that failed for good.
///
/// A drag in the layout editor has always shown an alert when it failed. The
/// other movers — the triggers, the saved-layout apply, the divider and
/// new-item relocations — failed into the log only, so the first sign was an
/// item that was not where it should be, with nothing to attach to a report.
/// Every one of them now goes through ``reportAutomaticMoveFailure``, which
/// saves the diagnostic report on its own and tells the user where it is.
extension MenuBarItemManager {
    /// How long one item's failures stay quiet after a report about it. A
    /// trigger in a reverting episode retries on its backoff for minutes;
    /// one report per item per episode is the useful rate.
    static let automaticMoveFailureReportCooldown: TimeInterval = 10 * 60

    /// Minimum spacing between reports about different items, so a saved
    /// layout that loses several items in one pass yields one report, not
    /// one per item. The others are still logged and their reports written.
    static let automaticMoveFailureReportSpacing: TimeInterval = 30

    /// Whether a failure is worth telling the user about at all.
    ///
    /// Deferrals — input still busy, a menu open, another move holding the
    /// bar, the condition changed, the target moved away, the item gone —
    /// resolve on their own on the next pass and would only produce noise.
    static nonisolated func failureDeservesReport(_ error: any Error) -> Bool {
        guard let error = error as? EventError else {
            return true
        }
        switch error {
        case .inputPauseTimedOut, .moveSuperseded, .menuTrackingActive, .moveEngineBusy, .staleDestination,
             .missingItemBounds:
            return false
        case .cannotComplete, .invalidEventSource, .missingMouseLocation, .eventCreationFailure,
             .eventOperationTimeout, .itemNotMovable, .itemResponseTimeout, .ownerUnresponsive,
             .eventWindowMismatch, .dropReverted, .moveTimedOut:
            return true
        }
    }

    /// Tells the user that an automatic move of `item` failed, at most once
    /// per item per ``automaticMoveFailureReportCooldown``.
    ///
    /// The diagnostic report is written to ``MoveFailureDiagnosticReport/automaticReportsDirectory``
    /// first, so it exists whether or not the user acts. When the Settings
    /// window is up the failure is shown there as a sheet with the report
    /// offered for saving elsewhere; otherwise a notification names the item
    /// and the report's location, and opening it reveals the file.
    ///
    /// - Parameters:
    ///   - source: Who asked for the move, for the message ("a trigger").
    func reportAutomaticMoveFailure(
        of item: MenuBarItem,
        to destination: MoveDestination?,
        expectedSection: MenuBarSection.Name?,
        error: any Error,
        source: String
    ) async {
        guard Self.failureDeservesReport(error) else {
            return
        }
        guard let appState else {
            return
        }
        let key = MenuBarItemTag.canonicalPersistentIdentifier(item.uniqueIdentifier)
        let now = Date()
        if let last = automaticMoveFailureReports[key],
           now.timeIntervalSince(last) < Self.automaticMoveFailureReportCooldown
        {
            MenuBarItemManager.diagLog.debug(
                "Not reporting the failed \(source) move of \(item.logString) again; reported \(Int(now.timeIntervalSince(last))) s ago"
            )
            return
        }
        if let last = lastAutomaticMoveFailureReport,
           now.timeIntervalSince(last) < Self.automaticMoveFailureReportSpacing
        {
            MenuBarItemManager.diagLog.debug(
                "Not reporting the failed \(source) move of \(item.logString); another failure was reported \(Int(now.timeIntervalSince(last))) s ago"
            )
            return
        }
        automaticMoveFailureReports[key] = now
        lastAutomaticMoveFailureReport = now

        let report = await MoveFailureDiagnosticReport.generate(
            for: .init(
                item: item,
                destination: destination,
                expectedSection: expectedSection,
                error: error,
                note: "Automatic move requested by \(source)."
            ),
            appState: appState
        )
        var savedURL: URL?
        do {
            savedURL = try report.writeToAutomaticReports()
        } catch {
            MenuBarItemManager.diagLog.error("Could not save the diagnostic report for \(item.logString): \(error)")
        }

        let title = String(localized: "Couldn't move \(item.displayName)")
        let description = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        MenuBarItemManager.diagLog.info(
            "Reporting the failed \(source) move of \(item.logString) to the user: \(description); report=\(savedURL?.lastPathComponent ?? "not saved")"
        )

        if let window = NSApp.window(withIdentifier: IceWindowIdentifier.settings.rawValue), window.isVisible {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            var lines = [String(localized: "\(description) — requested by \(source).")]
            if let suggestion = (error as? LocalizedError)?.recoverySuggestion {
                lines.append(suggestion)
            }
            alert.informativeText = lines.joined(separator: "\n\n")
            report.run(alert, in: window)
            return
        }

        let location = savedURL.map { url in
            let folder = url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            return String(localized: "A diagnostic report was saved to \(folder).")
        } ?? ""
        appState.userNotificationManager.requestAuthorization()
        appState.userNotificationManager.addRequest(
            with: .moveFailed,
            title: title,
            body: "\(description). \(location)",
            userInfo: savedURL.map { ["reportPath": $0.path] } ?? [:]
        )
    }
}
