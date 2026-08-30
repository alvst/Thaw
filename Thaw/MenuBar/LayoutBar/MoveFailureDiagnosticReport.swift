//
//  MoveFailureDiagnosticReport.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa
import UniformTypeIdentifiers

/// A self-contained, redacted description of a failed menu bar item move,
/// offered from the failure alert for attaching to a bug report.
///
/// A pasted log excerpt on its own cannot answer the questions that decide
/// a move investigation: what the display looks like, what the rest of the
/// bar looked like at the time, which settings the move engine ran under,
/// what each trigger targets, and whether the same mechanics had just
/// worked for another item. This gathers all of that into one text file
/// and runs it through ``DiagnosticRedactor`` so it can be posted publicly.
nonisolated struct MoveFailureDiagnosticReport {
    /// The move that failed.
    struct Failure {
        /// The item that did not move.
        let item: MenuBarItem

        /// Where it was supposed to go, when the caller still knows.
        let destination: MenuBarItemManager.MoveDestination?

        /// The section the destination lies in, when the caller knows.
        let expectedSection: MenuBarSection.Name?

        /// The error the move ended with.
        let error: any Error

        /// What the caller already tried, if anything.
        let note: String?

        init(
            item: MenuBarItem,
            destination: MenuBarItemManager.MoveDestination?,
            expectedSection: MenuBarSection.Name?,
            error: any Error,
            note: String? = nil
        ) {
            self.item = item
            self.destination = destination
            self.expectedSection = expectedSection
            self.error = error
            self.note = note
        }
    }

    /// Log categories the excerpt keeps: everything about enumerating and
    /// moving items, nothing that quotes a network, device, or script. The
    /// window-list chatter in `Bridging` is left out as noise; the move
    /// engine's own lines already summarize what each enumeration returned.
    static let logCategories: Set<String> = [
        "AppState",
        "ControlItem",
        "DisplaySettingsManager",
        "EventTap",
        "LayoutBarContainer",
        "LayoutBarItemView",
        "LayoutBarPaddingView",
        "Listener",
        "MenuBarItem",
        "MenuBarItemManager",
        "MenuBarItemService.Connection",
        "MenuBarItemSpacingManager",
        "MenuBarItemTriggers",
        "MenuBarManager",
        "MouseHelpers",
        "NSScreen",
        "SourcePIDCache",
        "StaleIdentifierLedger",
        "WindowInfo",
    ]

    /// How many matching log lines the excerpt keeps, newest last.
    static let logLineLimit = 800

    /// The redacted report text.
    let text: String

    /// A file name for the save panel.
    let suggestedFileName: String

    // MARK: Generation

    /// Builds the report for a failed move against the app's current state.
    @MainActor
    static func generate(for failure: Failure, appState: AppState) async -> MoveFailureDiagnosticReport {
        // Not `.onScreen`: items parked in a collapsed section are the ones
        // a failed hidden-section move is usually about.
        let liveItems = await MenuBarItem.getMenuBarItems(on: nil, option: .activeSpace, resolveSourcePID: false)

        var writer = Writer()
        writeHeader(to: &writer)
        writeFailure(failure, appState: appState, to: &writer)
        writeDisplays(to: &writer)
        writeSettings(appState: appState, to: &writer)
        writeCachedMenuBar(appState: appState, liveItems: liveItems, to: &writer)
        writeLiveMenuBar(liveItems, to: &writer)
        writeSavedLayout(appState: appState, to: &writer)
        writeTriggers(appState: appState, to: &writer)
        writeLogExcerpt(to: &writer)

        let redactor = DiagnosticRedactor(terms: redactionTerms(appState: appState))
        return MoveFailureDiagnosticReport(
            text: redactor.redact(writer.text),
            suggestedFileName: suggestedFileName(for: Date())
        )
    }

    // MARK: Presentation

    /// Presents `alert` with an added "Save Diagnostic Report…" button and
    /// saves this report when it is chosen.
    ///
    /// Shown as a sheet on `window` when there is one. An app-modal alert
    /// holds the main actor for as long as it is up, and the move engine
    /// runs on the main actor: in the field a trigger's move sat behind a
    /// modal failure alert for fifteen seconds with its synthetic press
    /// still down, and Control Center completed that orphaned drag by
    /// removing the item from the bar. A sheet returns immediately.
    @MainActor
    func run(_ alert: NSAlert, in window: NSWindow? = nil) {
        let notice = String(
            localized: "A diagnostic report describing this failure is available. Personal information is removed from it, so it can be attached to a bug report."
        )
        alert.informativeText = alert.informativeText.isEmpty ? notice : alert.informativeText + "\n\n" + notice
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Save Diagnostic Report…"))
        guard let window else {
            if alert.runModal() == .alertSecondButtonReturn {
                save()
            }
            return
        }
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn {
                save()
            }
        }
    }

    /// Where reports for failed automatic moves are written without asking:
    /// `~/Library/Logs/Thaw/Diagnostics`.
    static var automaticReportsDirectory: URL {
        DiagnosticLogger.shared.logDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    /// How many automatic reports are kept; the oldest are removed.
    static let automaticReportsKept = 20

    /// Writes the report into ``automaticReportsDirectory`` and prunes the
    /// folder to the newest ``automaticReportsKept`` reports.
    @discardableResult
    func writeToAutomaticReports() throws -> URL {
        let directory = Self.automaticReportsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(suggestedFileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        Self.pruneAutomaticReports(in: directory, keeping: Self.automaticReportsKept)
        return url
    }

    /// Removes all but the newest `keepCount` reports in `directory`.
    static func pruneAutomaticReports(in directory: URL, keeping keepCount: Int) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        }
        let reports = urls
            .filter { $0.pathExtension == "txt" }
            .sorted { modified($0) > modified($1) }
        for stale in reports.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    /// Asks where to save the report, writes it, and reveals it in Finder.
    @MainActor
    func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedFileName
        panel.canCreateDirectories = true
        panel.title = String(localized: "Save Diagnostic Report")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: Log excerpt

    /// Keeps the lines whose category is in ``logCategories``, newest
    /// `limit` of them. A line that does not parse as a log line (the file
    /// header, a continuation) is dropped.
    static func filterLogLines(_ lines: [String], limit: Int = logLineLimit) -> [String] {
        let kept = lines.filter { line in
            guard let category = logCategory(of: line) else {
                return false
            }
            return logCategories.contains(category)
        }
        return Array(kept.suffix(limit))
    }

    /// The `[Category]` field of a log line, which follows the timestamp
    /// and the level: `2026-08-28 22:16:43.817 [DEBUG] [MenuBarItemManager] …`.
    static func logCategory(of line: String) -> String? {
        guard let match = line.firstMatch(of: #/^\S+ \S+ \[[A-Z]+\] \[([^\]]+)\]/#) else {
            return nil
        }
        return String(match.1)
    }

    /// The file name offered by the save panel.
    static func suggestedFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "\(Constants.displayName)-move-diagnostic-\(formatter.string(from: date)).txt"
    }
}

// MARK: - Sections

private extension MoveFailureDiagnosticReport {
    /// Accumulates the report's lines.
    struct Writer {
        private(set) var lines: [String] = []

        var text: String {
            lines.joined(separator: "\n") + "\n"
        }

        mutating func heading(_ title: String) {
            lines.append("")
            lines.append("## \(title)")
        }

        mutating func line(_ text: String = "") {
            lines.append(text)
        }
    }

    static func writeHeader(to writer: inout Writer) {
        let commit = Bundle.main.infoDictionary?["GitCommitSHA"] as? String ?? "unknown"
        writer.line("\(Constants.displayName) move diagnostic report")
        writer.line("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        writer.line()
        writer.line(
            """
            Personal information has been removed: account and full names, the home \
            directory, network and device names, focus modes, locations, e-mail and IP \
            addresses. App bundle identifiers, menu bar item identifiers and window \
            geometry are kept because they are what the maintainers need. Please skim \
            the report before attaching it to a bug report.
            """
        )
        writer.heading("Environment")
        writer.line("\(Constants.displayName): \(Constants.versionString) (\(Constants.buildString)) commit \(commit)")
        writer.line("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        writer.line("Hardware: \(hardwareModel())")
        writer.line("Diagnostic logging: \(DiagnosticLogger.shared.isEnabled ? "enabled" : "disabled")")
    }

    @MainActor
    static func writeFailure(_ failure: Failure, appState: AppState, to writer: inout Writer) {
        let manager = appState.itemManager
        let cache = manager.itemCache

        writer.heading("Failure")
        writer.line("Error: \(describe(failure.error))")
        if let note = failure.note {
            writer.line("Note: \(note)")
        }
        writer.line("Expected section: \(failure.expectedSection?.logString ?? "unknown")")
        writer.line("Item: \(failure.item.logString)")
        for line in itemLines(failure.item, cache: cache, manager: manager) {
            writer.line(line)
        }
        if let destination = failure.destination {
            let target = destination.targetItem
            writer.line("Destination: \(destination.logString)")
            for line in itemLines(target, cache: cache, manager: manager) {
                writer.line(line)
            }
            if let liveTargetBounds = Bridging.getWindowBounds(for: target.windowID) {
                writer.line("  liveBounds=\(format(liveTargetBounds))")
            }
        } else {
            writer.line("Destination: not recorded by the caller (see the log excerpt)")
        }

        let lastMove = manager.lastMoveOperationTimestamp.map { instant in
            String(format: "%.1f s ago", (ContinuousClock.now - instant).milliseconds / 1000)
        } ?? "none this session"
        writer.line(
            "Manager state: bulkApply=\(manager.isBulkApplyInProgress) profileApply=\(manager.isApplyingProfileLayout) "
                + "resettingLayout=\(manager.isResettingLayout) restoringOrder=\(manager.isRestoringItemOrder) "
                + "startupSettling=\(manager.isInStartupSettling) controlItemsMissing=\(manager.areControlItemsMissing) "
                + "lastMove=\(lastMove)"
        )
    }

    @MainActor
    static func itemLines(
        _ item: MenuBarItem,
        cache: MenuBarItemManager.ItemCache,
        manager: MenuBarItemManager
    ) -> [String] {
        let section = cache.address(for: item.tag)?.section.logString ?? "not in cache"
        let owner = processDescription(item.ownerPID, application: item.owningApplication)
        let source = item.sourcePID.map { processDescription($0, application: item.sourceApplication) } ?? "unresolved"
        let movability = item.immovabilityReason?.logDescription ?? "movable"
        let timeout = manager.moveOperationTimeouts[item.tag].map { "\(Int($0.milliseconds)) ms" } ?? "default"
        return [
            "  identifier=\(item.tag.tagIdentifier) windowID=\(item.windowID) title=\(item.title ?? "nil")",
            "  bounds=\(format(item.bounds)) onScreen=\(item.isOnScreen) cachedSection=\(section)",
            "  owner=\(owner) source=\(source)",
            "  movability=\(movability) provisionalIdentity=\(item.hasProvisionalIdentity) "
                + "systemClone=\(item.isSystemClone) canBeHidden=\(item.canBeHidden) controlItem=\(item.isControlItem)",
            "  ownerUnresponsive=\(Bridging.isProcessUnresponsive(item.ownerPID)) "
                + "sourceUnresponsive=\(item.sourcePID.map { String(Bridging.isProcessUnresponsive($0)) } ?? "n/a") "
                + "ledgerUnresponsive=\(manager.failureLedger.isUnresponsive(item)) "
                + "ledgerBackoff=\(manager.failureLedger.isUnderBackoff(for: item)) moveTimeout=\(timeout)",
        ]
    }

    @MainActor
    static func writeDisplays(to writer: inout Writer) {
        let activeDisplayID = Bridging.getActiveMenuBarDisplayID()
        writer.heading("Displays")
        for (index, screen) in NSScreen.screens.enumerated() {
            let notch = screen.frameOfNotch.map(format) ?? "none"
            writer.line(
                "[\(index)] displayID=\(screen.displayID) frame=\(format(screen.frame)) "
                    + "visibleFrame=\(format(screen.visibleFrame)) scale=\(screen.backingScaleFactor) "
                    + "notch=\(notch) safeAreaTop=\(screen.safeAreaInsets.top) "
                    + "main=\(screen == NSScreen.main) activeMenuBar=\(screen.displayID == activeDisplayID)"
            )
        }
    }

    @MainActor
    static func writeSettings(appState: AppState, to writer: inout Writer) {
        writer.heading("Settings")
        writer.line("postMoveEventsToWindowOwner=\(MenuBarItem.postsMoveEventsToWindowOwner)")
        writer.line("discardStrayMoveEvents=\(defaultsValue(.discardStrayMoveEvents))")
        writer.line("enableAlwaysHiddenSection=\(appState.settings.advanced.enableAlwaysHiddenSection)")
        writer.line("useIceBar=\(defaultsValue(.useIceBar)) useIceBarOnlyOnNotchedDisplay=\(defaultsValue(.useIceBarOnlyOnNotchedDisplay))")
        writer.line("showOnClick=\(defaultsValue(.showOnClick)) showOnHover=\(defaultsValue(.showOnHover))")
    }

    @MainActor
    static func writeCachedMenuBar(appState: AppState, liveItems: [MenuBarItem], to writer: inout Writer) {
        let manager = appState.itemManager
        let cache = manager.itemCache
        writer.heading("Menu bar (cached sections, left to right)")
        writer.line("displayID=\(cache.displayID.map(String.init) ?? "nil")")
        for section in MenuBarSection.Name.allCases {
            let items = cache[section]
            writer.line("\(section.logString) (\(items.count)):")
            for item in items {
                writer.line("  \(compactDescription(of: item))")
            }
        }
        // The control item's own window reference is often nil; the divider
        // is still enumerable as a menu bar item by its tag.
        let dividers: [(name: MenuBarSection.Name, tag: MenuBarItemTag)] = [
            (.hidden, .hiddenControlItem),
            (.alwaysHidden, .alwaysHiddenControlItem),
        ]
        for divider in dividers {
            let windowID = appState.menuBarManager.controlItem(withName: divider.name)?.window
                .flatMap { CGWindowID(exactly: $0.windowNumber) }
                ?? liveItems.first { $0.tag == divider.tag }?.windowID
            guard let windowID else {
                writer.line("\(divider.name.logString) divider: not found")
                continue
            }
            let bounds = Bridging.getWindowBounds(for: windowID).map(format) ?? "unknown"
            writer.line("\(divider.name.logString) divider: windowID=\(windowID) bounds=\(bounds)")
        }
        writer.line("Trigger-controlled identifiers: \(manager.triggerControlledItemIdentifiers.sorted())")
        writer.line("Pending trigger restoration: \(manager.triggerLayoutRestorationItemIdentifiers.sorted())")
    }

    static func writeLiveMenuBar(_ items: [MenuBarItem], to writer: inout Writer) {
        writer.heading("Menu bar (live enumeration, active space, source processes unresolved)")
        for item in items.sorted(by: { $0.bounds.minX < $1.bounds.minX }) {
            writer.line("  \(compactDescription(of: item))")
        }
    }

    @MainActor
    static func writeSavedLayout(appState: AppState, to writer: inout Writer) {
        writer.heading("Saved layout")
        let order = appState.itemManager.savedSectionOrder
        for key in order.keys.sorted() {
            writer.line("\(key): \(order[key] ?? [])")
        }
    }

    /// Triggers by index, with condition kinds only: a condition's value
    /// (a network name, a location, a script path) is exactly what the
    /// report must not carry, and the kind is what a move needs.
    @MainActor
    static func writeTriggers(appState: AppState, to writer: inout Writer) {
        let triggersManager = appState.settings.triggers
        writer.heading("Triggers (condition kinds only)")
        for (index, trigger) in triggersManager.triggers.enumerated() {
            let kinds = trigger.allConditions.map(\.kind.rawValue)
            writer.line(
                "#\(index + 1) enabled=\(trigger.isEnabled) targets=\(trigger.allItemIdentifiers) "
                    + "reveal=\(trigger.revealSection.logString) hide=\(trigger.hideSection.logString) "
                    + "combinator=\(trigger.combinator.rawValue) conditions=\(kinds) "
                    + "status=\(statusDescription(triggersManager.runtimeStatus(for: trigger)))"
            )
        }
    }

    static func writeLogExcerpt(to writer: inout Writer) {
        let logger = DiagnosticLogger.shared
        writer.heading("Recent log (categories: \(logCategories.sorted().joined(separator: ", ")); newest \(logLineLimit) lines)")
        if !logger.isEnabled {
            writer.line("Diagnostic logging is disabled; the most recent log file may predate this failure.")
        }
        guard
            let url = logger.currentLogFile ?? logger.latestLogFile,
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            writer.line("(no log file available)")
            return
        }
        writer.line("File: \(url.lastPathComponent)")
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        for line in filterLogLines(lines) {
            writer.line(line)
        }
    }

    // MARK: Redaction terms

    /// Everything the live state and the user's rules say is personal.
    @MainActor
    static func redactionTerms(appState: AppState) -> [DiagnosticRedactor.Term] {
        var terms = DiagnosticRedactor.accountTerms()
        let triggersManager = appState.settings.triggers
        let state = triggersManager.currentSystemState
        if let ssid = state.wifiSSID {
            terms.append(.init(ssid, placeholder: "<wifi-network>"))
        }
        terms += state.connectedBluetoothDeviceNames.map { .init($0, placeholder: "<bluetooth-device>") }
        if let audio = state.audioOutputDeviceName {
            terms.append(.init(audio, placeholder: "<audio-device>"))
        }
        if let focus = state.activeFocusModeName {
            terms.append(.init(focus, placeholder: "<focus-mode>"))
        }
        for trigger in triggersManager.triggers {
            if !trigger.name.isEmpty {
                terms.append(.init(trigger.name, placeholder: "<trigger-name>"))
            }
            for condition in trigger.allConditions {
                terms += conditionTerms(condition)
            }
        }
        return terms
    }

    static func conditionTerms(_ condition: TriggerCondition) -> [DiagnosticRedactor.Term] {
        switch condition {
        case let .wifiSSID(name):
            [.init(name, placeholder: "<wifi-network>")]
        case let .bluetoothConnected(name):
            [.init(name, placeholder: "<bluetooth-device>")]
        case let .audioOutput(contains):
            [.init(contains, placeholder: "<audio-device>")]
        case let .focusMode(name):
            [.init(name, placeholder: "<focus-mode>")]
        case let .nearLocation(latitude, longitude, _, label):
            [
                .init(label, placeholder: "<location>"),
                .init(String(latitude), placeholder: "<coordinates>"),
                .init(String(longitude), placeholder: "<coordinates>"),
            ]
        case let .scriptResult(path, expectedOutput):
            [
                .init(path, placeholder: "<script-path>"),
                .init(expectedOutput, placeholder: "<script-output>"),
            ]
        default:
            []
        }
    }

    // MARK: Formatting

    static func describe(_ error: any Error) -> String {
        let description = String(describing: error)
        if let localized = (error as? LocalizedError)?.errorDescription {
            return "\(description) — \(localized)"
        }
        return description
    }

    static func compactDescription(of item: MenuBarItem) -> String {
        let source = item.sourcePID.map(String.init) ?? "unresolved"
        let control = item.isControlItem ? " [control item]" : ""
        return "\(item.tag.tagIdentifier) windowID=\(item.windowID) minX=\(format(item.bounds.minX)) "
            + "width=\(format(item.bounds.width)) onScreen=\(item.isOnScreen) source=\(source)\(control)"
    }

    /// The activation policy matters for the source app: a regular app whose
    /// window is closed can be napped, and both revert episodes in the field
    /// logs began right after a long idle stretch.
    static func processDescription(_ pid: pid_t, application: NSRunningApplication?) -> String {
        guard let application else {
            return "pid \(pid) (not a running application)"
        }
        let identity = application.bundleIdentifier
            ?? "no bundle identifier; name=\(application.localizedName ?? "unknown")"
        let policy = switch application.activationPolicy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown"
        }
        return "pid \(pid) (\(identity)) policy=\(policy)"
    }

    /// Other triggers' names stay out of the report; the fact of an
    /// override is what matters.
    static func statusDescription(_ status: MenuBarItemTriggerRuntimeStatus) -> String {
        if case .overridden = status {
            return "overridden"
        }
        return String(describing: status)
    }

    static func defaultsValue(_ key: Defaults.Key) -> String {
        Defaults.object(forKey: key).map { String(describing: $0) } ?? "default"
    }

    static func format(_ rect: CGRect) -> String {
        "(x=\(format(rect.minX)) y=\(format(rect.minY)) w=\(format(rect.width)) h=\(format(rect.height)))"
    }

    static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    static func hardwareModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "unknown"
        }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? "unknown"
    }
}
