//
//  MenuBarItemTag.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation

// MARK: - MenuBarItemTag

/// An identifier for a menu bar item.
struct MenuBarItemTag: Hashable, CustomStringConvertible {
    /// The namespace of the item identified by this tag.
    let namespace: Namespace

    /// The title of the item identified by this tag.
    let title: String

    /// The window identifier of the item identified by this tag.
    let windowID: CGWindowID?

    /// The index of the item within its (namespace, title) group.
    let instanceIndex: Int

    /// A Boolean value that indicates whether the item identified
    /// by this tag is a system item.
    var isSystemItem: Bool {
        switch namespace {
        case .controlCenter, .systemUIServer, .textInputMenuAgent, .weather, .passwords, .screenCaptureUI, .ssMenuAgent, .thaw, .gamePolicyAgent:
            return true
        case .menuBarAgent:
            if #available(macOS 27, *) {
                return true
            }
            return false
        case .string, .uuid, .null:
            return false
        }
    }

    /// A Boolean value that indicates whether this item should be rendered as a
    /// fixed system anchor in the layout UI.
    ///
    /// macOS 27 exposes Apple modules as children of `MenuBarAgent`. These are
    /// live AX items that should remain visible at their real positions, but Thaw
    /// must not treat them as draggable or persist them into user layout order.
    var isLayoutAnchoredSystemItem: Bool {
        if MenuBarItemTag.immovableItems.contains(where: { $0.namespace == namespace && $0.title == title }) {
            return true
        }

        if MenuBarItemTag.fixedSystemAgentNamespaces.contains(namespace) {
            return true
        }

        if #available(macOS 27, *) {
            if namespace == .menuBarAgent,
               MenuBarItemTag.menuBarAgentAnchoredModuleTitles.contains(title)
            {
                return true
            }
        }

        return false
    }

    /// A Boolean value that indicates whether the item identified
    /// by this tag can be moved.
    var isMovable: Bool {
        !isLayoutAnchoredSystemItem
    }

    /// A Boolean value that indicates whether the item identified
    /// by this tag can be hidden.
    var canBeHidden: Bool {
        !isLayoutAnchoredSystemItem &&
            !MenuBarItemTag.nonHideableItems.contains(where: { $0.namespace == namespace && $0.title == title }) &&
            !(namespace.isUUID && title == "AudioVideoModule")
    }

    /// A Boolean value that indicates whether this tag represents a
    /// dynamically-named hosting-process item (Live Activities, etc.)
    /// with the pattern `<hostingProcess>:Item-\d+`.
    var isControlCenterGenericItem: Bool {
        // macOS 26: the hosting namespace is Control Center; macOS 27: MenuBarAgent
        // (see isMenuBarHostingNamespace). The generic-slot title test is shared
        // with the marker-pair resolver so both stay in sync.
        namespace.isMenuBarHostingNamespace && MarkerPairResolver.isGenericControlCenterTitle(title)
    }

    /// A Boolean value that indicates whether the item identified
    /// by this tag is a control item owned by Ice.
    var isControlItem: Bool {
        MenuBarItemTag.controlItems.contains(where: { $0.namespace == namespace && $0.title == title }) ||
            title.contains(".Spacer.")
    }

    /// A Boolean value that indicates whether the item identified
    /// by this tag is a "BentoBox" item owned by the menu bar hosting process.
    var isBentoBox: Bool {
        namespace.isMenuBarHostingNamespace && title.hasPrefix("BentoBox")
    }

    /// A Boolean value that indicates whether the item identified
    /// by this tag is a system-created clone of an actual item,
    /// and therefore invalid for management.
    ///
    /// The title is a stable name the WindowServer assigns to clone
    /// windows, but the namespace varies: it can be a UUID, the owning
    /// process name (Window Server) when the source PID never resolves,
    /// or even a real bundle ID when the clone spatially mis-matches a
    /// nearby app. Matching on the title alone catches every variant;
    /// gating on a UUID namespace missed the process-name and bundle-ID
    /// clones seen in the field.
    var isSystemClone: Bool {
        title == "System Status Item Clone"
    }

    /// A textual representation of the tag.
    var description: String {
        var result = String(describing: namespace)
        if !title.isEmpty {
            result.append(":\(title)")
        }
        if instanceIndex > 0 {
            result.append(":\(instanceIndex)")
        }
        if let windowID, !isSystemItem {
            result.append(" (windowID: \(windowID))")
        }
        return result
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(namespace)
        hasher.combine(title)
        hasher.combine(instanceIndex)
        if !isSystemItem {
            hasher.combine(windowID)
        }
    }

    static func == (lhs: MenuBarItemTag, rhs: MenuBarItemTag) -> Bool {
        if lhs.namespace != rhs.namespace || lhs.title != rhs.title || lhs.instanceIndex != rhs.instanceIndex {
            return false
        }
        if lhs.isSystemItem {
            return true
        }
        return lhs.windowID == rhs.windowID
    }

    /// Returns a Boolean value that indicates whether the given tag
    /// matches this tag, ignoring their window identifiers.
    func matchesIgnoringWindowID(_ other: MenuBarItemTag) -> Bool {
        namespace == other.namespace && title == other.title && instanceIndex == other.instanceIndex
    }

    /// A stable string identifier that uniquely identifies this tag
    /// across window ID changes (e.g. app restarts). Includes the
    /// instance index when it is nonzero so that multiple items from
    /// the same app with the same title are distinguishable.
    var tagIdentifier: String {
        if instanceIndex > 0 {
            return "\(namespace):\(title):\(instanceIndex)"
        }
        return "\(namespace):\(title)"
    }

    /// Creates a tag with the given namespace, title, window identifier,
    /// and instance index.
    init(namespace: Namespace, title: String, windowID: CGWindowID? = nil, instanceIndex: Int = 0) {
        self.namespace = namespace
        self.title = title
        self.windowID = windowID
        self.instanceIndex = instanceIndex
    }

    /// Creates a tag for the control item with the given identifier.
    private init(controlItem identifier: ControlItem.Identifier) {
        self.init(namespace: .thaw, title: identifier.rawValue, instanceIndex: 0)
    }
}

// MARK: MenuBarItemTag Constants

extension MenuBarItemTag {
    // MARK: Special Item Lists

    /// An array of tags for items whose movement is prevented by macOS.
    ///
    /// These items have fixed positions at the trailing end of the menu bar,
    /// and cannot be hidden.
    ///
    /// This list contains the "Clock", "Control Center", and "Screen Sharing" (ssMenuAgent) items.
    static var immovableItems: [MenuBarItemTag] { [clock, controlCenter, ssMenuAgent] }

    /// An array of tags for items that can be moved, but cannot be hidden.
    static var nonHideableItems: [MenuBarItemTag] { [visibleControlItem, audioVideoModule, faceTime, screenCaptureUI, gameMode] }

    /// An array of tags for items representing Ice's control items.
    static let controlItems = ControlItem.Identifier.allCases.map(\.tag)

    /// Apple modules currently observed under `com.apple.MenuBarAgent` on
    /// macOS 27. These names come from `VisibleCC` keys and
    /// `TrailingItemPreferredPositions` entries such as `module:Clock`.
    static let menuBarAgentAnchoredModuleTitles: Set<String> = [
        "AudioVideoModule",
        "Battery",
        "BentoBox-0",
        "Bluetooth",
        "Clock",
        "Display",
        "FocusModes",
        "MusicRecognition",
        "NowPlaying",
        "ScreenMirroring",
        "Sound",
        "WiFi",
    ]

    /// Separate Apple/system agents that Thaw should display but not move.
    private static let fixedSystemAgentNamespaces: Set<Namespace> = [
        .gamePolicyAgent,
        .screenCaptureUI,
        .ssMenuAgent,
    ]

    // MARK: Control Items

    /// The tag for Ice's control item for the "Visible" section.
    static let visibleControlItem = MenuBarItemTag(controlItem: .visible)

    /// The tag for Ice's control item for the "Hidden" section.
    static let hiddenControlItem = MenuBarItemTag(controlItem: .hidden)

    /// The tag for Ice's control item for the "Always-Hidden" section.
    static let alwaysHiddenControlItem = MenuBarItemTag(controlItem: .alwaysHidden)

    // MARK: Other Special Items

    /// The namespace used by system-owned menu bar items (Clock, BentoBox, AudioVideoModule…).
    ///
    /// On macOS 26 the hosting process is Control Center; on macOS 27+ it is MenuBarAgent.
    private static var systemHostNamespace: Namespace {
        if #available(macOS 27, *) { .menuBarAgent } else { .controlCenter }
    }

    /// The tag for the system item that appears in the menu bar
    /// during screen or audio capture.
    static var audioVideoModule: MenuBarItemTag { MenuBarItemTag(namespace: systemHostNamespace, title: "AudioVideoModule") }

    /// The tag for the system "Clock" item.
    static var clock: MenuBarItemTag { MenuBarItemTag(namespace: systemHostNamespace, title: "Clock") }

    /// The tag for the system "Control Center" item.
    static var controlCenter: MenuBarItemTag { MenuBarItemTag(namespace: systemHostNamespace, title: "BentoBox-0") }

    /// The tag for the system "FaceTime" item.
    static var faceTime: MenuBarItemTag { MenuBarItemTag(namespace: systemHostNamespace, title: "FaceTime") }

    /// The tag for the system "Music Recognition" item.
    static var musicRecognition: MenuBarItemTag { MenuBarItemTag(namespace: systemHostNamespace, title: "MusicRecognition") }

    /// The tag for the system item that appears in the menu bar
    /// during recordings started by the macOS "Screenshot" tool.
    static let screenCaptureUI = MenuBarItemTag(namespace: .screenCaptureUI, title: "Item-0")

    /// The tag for the system "Siri" item.
    static let siri = MenuBarItemTag(namespace: .systemUIServer, title: "Siri")

    /// The tag for the system "SSMenuAgent" item (Screen Sharing menu extra).
    ///
    /// macOS prevents this item from being repositioned via Command+drag.
    /// The item visually follows the cursor during the drag, but springs
    /// back to its original position on mouse-up.
    static let ssMenuAgent = MenuBarItemTag(namespace: .ssMenuAgent, title: "Item-0")

    /// The tag for the system "Time Machine" item.
    static let timeMachine = MenuBarItemTag(namespace: .systemUIServer, title: "com.apple.menuextra.TimeMachine")

    /// The tag for the system "Game Mode" item.
    static let gameMode = MenuBarItemTag(namespace: .gamePolicyAgent, title: "Item-0")
}

// MARK: - MenuBarItemTag.Namespace

extension MenuBarItemTag {
    /// A type that represents a menu bar item namespace.
    enum Namespace: Hashable, CustomStringConvertible {
        /// The `null` namespace.
        case null
        /// A namespace represented by a string.
        case string(String)
        /// A namespace represented by a UUID.
        case uuid(UUID)

        /// A textual representation of the namespace.
        var description: String {
            switch self {
            case .null: "null"
            case let .string(string): string
            case let .uuid(uuid): uuid.uuidString
            }
        }

        /// A Boolean value that indicates whether this namespace is
        /// the `null` namespace.
        var isNull: Bool {
            switch self {
            case .null: true
            case .string, .uuid: false
            }
        }

        /// A Boolean value that indicates whether this namespace is
        /// represented by a string.
        var isString: Bool {
            switch self {
            case .string: true
            case .uuid, .null: false
            }
        }

        /// A Boolean value that indicates whether this namespace is
        /// represented by a UUID.
        var isUUID: Bool {
            switch self {
            case .uuid: true
            case .null, .string: false
            }
        }

        /// A Boolean value that indicates whether this namespace is the system
        /// process that owns menu bar item windows at the CG layer.
        ///
        /// On macOS 26 the hosting process is Control Center
        /// (`com.apple.controlcenter`); on macOS 27 and later it is
        /// MenuBarAgent (`com.apple.MenuBarAgent`).
        var isMenuBarHostingNamespace: Bool {
            if #available(macOS 27, *) {
                return self == .menuBarAgent
            } else {
                return self == .controlCenter
            }
        }

        /// Creates a namespace with the given optional value.
        ///
        /// - Parameter value: An optional value for the namespace.
        ///
        /// - Returns: A namespace represented by a string when `value`
        ///   is not `nil`. Otherwise, the `null` namespace.
        static func optional(_ value: String?) -> Namespace {
            value.map { .string($0) } ?? .null
        }
    }
}

// MARK: MenuBarItemTag.Namespace Constants

extension MenuBarItemTag.Namespace {
    /// The namespace for the "Thaw" process.
    static let thaw = string(Constants.bundleIdentifier)

    /// The namespace for the "Control Center" process.
    static let controlCenter = string("com.apple.controlcenter")

    /// The namespace for the "MenuBarAgent" process (macOS 27+).
    static let menuBarAgent = string("com.apple.MenuBarAgent")

    /// The namespace for the "PasswordsMenuBarExtra" process.
    static let passwords = string("com.apple.Passwords.MenuBarExtra")

    /// The namespace for the "screencaptureui" process.
    static let screenCaptureUI = string("com.apple.screencaptureui")

    /// The namespace for the "SystemUIServer" process.
    static let systemUIServer = string("com.apple.systemuiserver")

    /// The namespace for the "TextInputMenuAgent" process.
    static let textInputMenuAgent = string("com.apple.TextInputMenuAgent")

    /// The namespace for the "SSMenuAgent" process (Screen Sharing menu extra).
    static let ssMenuAgent = string("com.apple.SSMenuAgent")

    /// The namespace for the "GamePolicyAgent" process (Game Mode).
    static let gamePolicyAgent = string("GamePolicyAgent")

    /// The namespace for the "WeatherMenu" process.
    static let weather = string("com.apple.weather.menu")
}
