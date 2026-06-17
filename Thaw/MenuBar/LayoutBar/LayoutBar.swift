//
//  LayoutBar.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct LayoutBar: View {
    private struct Representable: NSViewRepresentable {
        let appState: AppState
        let section: MenuBarSection.Name

        func makeNSView(context _: Context) -> LayoutBarScrollView {
            LayoutBarScrollView(appState: appState, section: section)
        }

        func updateNSView(_: LayoutBarScrollView, context _: Context) {
            // Intentionally empty: `LayoutBarScrollView` wires itself to shared
            // state during initialization, so subsequent updates arrive through
            // its internal observers rather than SwiftUI's representable hook.
        }
    }

    @EnvironmentObject var appState: AppState
    @ObservedObject var imageCache: MenuBarItemImageCache

    let section: MenuBarSection.Name

    private var backgroundShape: some InsettableShape {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        mainContent
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .menuBarItemContainer(appState: appState)
            .containerShape(backgroundShape)
            .clipShape(backgroundShape)
            .contentShape([.interaction, .focusEffect], backgroundShape)
            .overlay {
                backgroundShape
                    .strokeBorder(.quaternary)
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        // macOS 27: items in concealed sections can't be image-captured (they're
        // hidden by the assertion), so `cacheFailed` is often true even though the
        // user must still be able to drag items between sections. Always render the
        // interactive bar there — items without a cached image show a placeholder
        // but stay draggable. (≤26 keeps the blank-placeholder behavior, which
        // covers the genuine "items haven't loaded yet" case.)
        if !Constants.supportsSectionHiding {
            Representable(appState: appState, section: section)
        } else if imageCache.cacheFailed(for: section) {
            // Avoid flicker during rapid cache refreshes; hold a blank placeholder instead of the error text.
            Color.clear
                .frame(height: 20)
        } else {
            Representable(appState: appState, section: section)
        }
    }
}
