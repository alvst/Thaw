//
//  DisplayDiagnostics.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Combine
import CoreGraphics
import Darwin

/// Diagnostic-only instrumentation that records a per-display inventory and
/// periodic memory/cache counters.
///
/// The inventory characterizes unusual streamed displays (the Apple Vision Pro
/// Mac Virtual Display, an iPad Sidecar) that never expose a valid menu bar, so
/// a reliable exclusion predicate can be scoped from real field data instead of
/// guesswork. The resource snapshot charts process memory and the caches most
/// likely to grow, to confirm the memory-growth vector behind issue #680.
///
/// All output flows through DiagLog, which writes to the diagnostic log file
/// only when diagnostic logging is enabled, so this has no effect on a normal
/// release run beyond a lightweight idle timer.
@MainActor
final class DisplayDiagnostics {
    /// Diagnostic logger for display diagnostics.
    private let diagLog = DiagLog(category: "DisplayDiagnostics")

    /// The shared app state.
    private weak var appState: AppState?

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// Performs the initial setup, logging the inventory once and starting the
    /// screen-change and periodic resource observers.
    func performSetup(with appState: AppState) {
        self.appState = appState

        logDisplayInventory(reason: "startup")

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logDisplayInventory(reason: "screenParametersChanged")
            }
            .store(in: &cancellables)

        // Periodic resource snapshot to chart memory growth over a long session.
        // The body is gated on diagnostic logging so it stays idle otherwise.
        Timer.publish(every: 30, tolerance: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.logResourceSnapshot()
            }
            .store(in: &cancellables)
    }

    /// Logs one line per connected display describing its identity and state.
    private func logDisplayInventory(reason: String) {
        guard DiagnosticLogger.shared.isEnabled else { return }

        let excluded = Bridging.excludedDisplayID
        let managedIDs = Set(NSScreen.managedScreens.map(\.displayID))

        diagLog.debug("displayInventory (\(reason)): \(NSScreen.screens.count) screen(s), excludedDisplayID=\(excluded.map(String.init) ?? "none")")

        for screen in NSScreen.screens {
            let id = screen.displayID
            let frame = screen.frame
            let frameStr = "{{\(Int(frame.origin.x)),\(Int(frame.origin.y))},{\(Int(frame.width)),\(Int(frame.height))}}"
            diagLog.debug(
                "display=\(id) "
                    + "name=\"\(screen.localizedName)\" "
                    + "frame=\(frameStr) "
                    + "scale=\(screen.backingScaleFactor) "
                    + "notch=\(screen.hasNotch) "
                    + "builtin=\(CGDisplayIsBuiltin(id) != 0) "
                    + "online=\(CGDisplayIsOnline(id) != 0) "
                    + "active=\(CGDisplayIsActive(id) != 0) "
                    + "asleep=\(CGDisplayIsAsleep(id) != 0) "
                    + "mirrorSet=\(CGDisplayIsInMirrorSet(id) != 0) "
                    + "mirrors=\(CGDisplayMirrorsDisplay(id)) "
                    + "stereo=\(CGDisplayIsStereo(id) != 0) "
                    + "vendor=\(CGDisplayVendorNumber(id)) "
                    + "model=\(CGDisplayModelNumber(id)) "
                    + "serial=\(CGDisplaySerialNumber(id)) "
                    + "unit=\(CGDisplayUnitNumber(id)) "
                    + "managed=\(managedIDs.contains(id))"
            )
        }
    }

    /// Logs a snapshot of process memory and the caches most likely to grow.
    private func logResourceSnapshot() {
        guard DiagnosticLogger.shared.isEnabled else { return }
        guard let appState else { return }

        let images = appState.imageCache.images
        let imageBytes = images.values.reduce(0) { $0 + $1.cgImage.bytesPerRow * $1.cgImage.height }

        let footprint = Self.physicalFootprintBytes()
        let footprintStr = footprint.map { "\($0 / 1_048_576) MB" } ?? "unknown"

        diagLog.debug(
            "resourceSnapshot: "
                + "footprint=\(footprintStr) "
                + "overlayPanels=\(appState.appearanceManager.overlayPanels.count) "
                + "imageCacheCount=\(images.count) "
                + "imageCacheBytes=\(imageBytes / 1024) KB "
                + "averageColors=\(appState.menuBarManager.averageColors.count) "
                + "screens=\(NSScreen.screens.count) "
                + "managedScreens=\(NSScreen.managedScreens.count)"
        )
    }

    /// Returns the process's physical memory footprint in bytes, matching the
    /// value Activity Monitor reports, or nil if it could not be read.
    private static func physicalFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
}
