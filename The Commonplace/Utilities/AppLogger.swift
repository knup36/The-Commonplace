// AppLogger.swift
// Commonplace
//
// Lightweight logging utility for surfacing errors in critical code paths.
// Replaces silent try? swallowing with structured console output.
//
// Design philosophy:
//   - Zero dependencies — pure Swift, no third-party frameworks
//   - No analytics, no crash reporting, no server calls — console only for now
//   - Structured by domain so Xcode console can be filtered by prefix
//   - Foundation for future crash reporting (e.g. Sentry) if needed
//
// Usage:
//   // Logging an error with context
//   AppLogger.error("Failed to save context", domain: .swiftData, error: error)
//
//   // Logging a warning (no Error object)
//   AppLogger.warning("Preview image missing for entry", domain: .media)
//
//   // Logging info (development only — stripped in release)
//   AppLogger.info("Readwise sync started", domain: .api)
//
// Adding a new domain:
//   Add a new case to the Domain enum below. That's it.
//
// Console output format:
//   [Domain] ❌ Message — underlying error description
//   [Domain] ⚠️ Message
//   [Domain] ℹ️ Message

import Foundation

enum AppLogger {

    // MARK: - Domains

    /// Log domains — used as prefixes in console output for easy filtering.
    enum Domain: String {
        case swiftData  = "SwiftData"
        case media      = "Media"
        case api        = "API"
        case iCloud     = "iCloud"
        case migration  = "Migration"
        case search     = "Search"
        case navigation = "Navigation"
        case general    = "General"
    }

    // MARK: - Public API

    /// Log an error with an associated Swift Error object.
    /// Always prints — errors should never be silent.
    static func error(
        _ message: String,
        domain: Domain,
        error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        print("[\(domain.rawValue)] ❌ \(message) — \(error.localizedDescription) (\(location))")
    }

    /// Log a warning — something unexpected but not necessarily an error.
    static func warning(
        _ message: String,
        domain: Domain,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        print("[\(domain.rawValue)] ⚠️ \(message) (\(location))")
    }

    /// Log informational messages — useful during development.
    /// Compiled out in release builds to avoid console noise in production.
    static func info(
        _ message: String,
        domain: Domain,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        print("[\(domain.rawValue)] ℹ️ \(message) (\(location))")
        #endif
    }
}
