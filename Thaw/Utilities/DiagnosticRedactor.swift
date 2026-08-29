//
//  DiagnosticRedactor.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// Removes personal information from diagnostic text before it leaves the
/// Mac.
///
/// A diagnostic report is written to be attached to a public bug report, so
/// it has to keep what a maintainer needs — app bundle identifiers, menu bar
/// item identifiers, window geometry — and drop what identifies the person:
/// account and full names, the home directory, network and device names,
/// focus modes, locations, e-mail and IP addresses. Two layers do that.
/// Exact terms come from live state (the current account, the Wi-Fi network,
/// the values in the user's trigger conditions) and are replaced wherever
/// they appear; general patterns then catch the same categories in any log
/// line that mentions one the caller could not know about.
nonisolated struct DiagnosticRedactor {
    /// An exact string to replace wherever it appears.
    struct Term: Hashable {
        /// The text to remove.
        let value: String

        /// What to put in its place.
        let placeholder: String

        init(_ value: String, placeholder: String) {
            self.value = value
            self.placeholder = placeholder
        }
    }

    /// Terms shorter than this are ignored: replacing every "al" or "Mac"
    /// would mangle identifiers without protecting anything.
    static let minimumTermLength = 3

    /// The exact terms, longest first, so a value that contains another
    /// value is replaced before its substring can be.
    let terms: [Term]

    init(terms: [Term]) {
        let usable = Set(terms.filter { $0.value.count >= Self.minimumTermLength })
        self.terms = usable.sorted { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count > rhs.value.count
            }
            return lhs.value < rhs.value
        }
    }

    /// Terms for the current macOS account: the home directory, the login
    /// name, and each part of the full name.
    static func accountTerms(
        userName: String = NSUserName(),
        fullName: String = NSFullUserName(),
        homeDirectory: String = NSHomeDirectory()
    ) -> [Term] {
        var terms = [
            Term(homeDirectory, placeholder: "~"),
            Term(userName, placeholder: "<user>"),
        ]
        for part in fullName.split(whereSeparator: \.isWhitespace) {
            terms.append(Term(String(part), placeholder: "<user>"))
        }
        return terms
    }

    /// Returns `text` with every term and every recognized pattern replaced.
    func redact(_ text: String) -> String {
        var result = text
        for term in terms {
            result = result.replacingOccurrences(
                of: term.value,
                with: term.placeholder,
                options: [.caseInsensitive]
            )
        }
        // Any home directory, not only the current account's.
        result = result.replacing(#//Users/[^/\s"'`)\]]+/#, with: "/Users/<user>")
        result = result.replacing(#/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/#, with: "<email>")
        result = result.replacing(#/\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b/#, with: "<mac-address>")
        result = result.replacing(#/\b(?:\d{1,3}\.){3}\d{1,3}\b/#, with: "<ip-address>")
        // A latitude/longitude pair. Menu bar geometry is logged with one
        // decimal, so "(1425.0, 0.0, 38.0, 33.0)" is left alone.
        result = result.replacing(#/-?\d{1,3}\.\d{3,}\s*,\s*-?\d{1,3}\.\d{3,}/#, with: "<coordinates>")
        return result
    }
}
