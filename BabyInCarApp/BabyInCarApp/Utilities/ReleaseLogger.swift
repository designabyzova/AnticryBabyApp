//
//  ReleaseLogger.swift
//  BabyInCarApp
//
//  Silences print() in Release builds to prevent log spam in production.
//  This module-level function shadows Swift.print() so all existing
//  print() calls become no-ops without modifying any other files.
//

#if !DEBUG
@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    // Silent in Release builds — no log output in App Store builds
}
#endif
