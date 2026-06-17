//
//  ThawAssessmentModeHiding.h
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//
//  Objective-C wrapper around the private MenuBarClientCore "Assessment Mode"
//  assertion, the only supported macOS 27 mechanism that truly hides (and
//  reflows) menu bar items. The private classes are resolved at runtime and the
//  whole path is wrapped in @try/@catch, so an absent or changed API degrades
//  to "unavailable" rather than crashing — the same defensive pattern used by
//  ThawVirtualDisplay.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Whether the Assessment Mode hiding API is present on this system
/// (MenuBarClientCore + the MBAssessmentMode* classes). Returns NO on any OS
/// where the private API is missing, in which case hiding is simply unavailable.
BOOL ThawAssessmentModeHidingAvailable(void);

/// Activates a menu bar visibility restriction.
///
/// The restriction is an *allowlist*: every menu bar item whose owner is NOT in
/// the allowlists is hidden, and the bar reflows. To hide specific items, pass
/// everything *except* them.
///
/// - Parameters:
///   - allowedBundleIdentifiers: bundle identifiers of third-party apps whose
///     items remain visible.
///   - allowedSystemItems: identifiers (NSNumbers) of Apple system / Control
///     Center items that remain visible. Pass all of them to keep system items.
///   - onFailure: an optional block invoked (on the main queue) if the
///     assertion's *asynchronous* activation reports an error. Activation
///     completes after this function has already returned a handle, so the
///     returned handle can be a dud that controls nothing; callers should use
///     this callback to tear the handle down and retry. Not called on success.
/// - Returns: an opaque, retained handle that keeps the restriction active for
///   as long as it is alive, or NULL if the API is unavailable or activation
///   could not even be started. The restriction is bound to this process, so it
///   is automatically dropped if Thaw exits or crashes. Pass the handle to
///   ThawAssessmentModeHidingInvalidate to reveal the items again.
void *_Nullable ThawAssessmentModeHidingActivate(
    NSArray<NSString *> *allowedBundleIdentifiers,
    NSArray<NSNumber *> *allowedSystemItems,
    void (^_Nullable onFailure)(void));

/// Invalidates a handle returned by ThawAssessmentModeHidingActivate, revealing
/// the previously hidden items, and releases it. Safe to call with NULL.
void ThawAssessmentModeHidingInvalidate(void *_Nullable handle);

NS_ASSUME_NONNULL_END
