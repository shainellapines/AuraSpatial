//
//  Formatting.swift
//  AuraSpatial
//
//  Small text helpers shared by every screen, so numbers read the same
//  everywhere - and so "1 nodes" can't happen again.
//

import Foundation

extension Int {
    /// `1.counted("sound")` -> "1 sound", `3.counted("sound")` -> "3 sounds".
    func counted(_ singular: String, plural: String? = nil) -> String {
        let word = self == 1 ? singular : (plural ?? singular + "s")
        return "\(self) \(word)"
    }
}

enum AuraFormat {
    /// "2.4 m"
    static func meters(_ value: Double) -> String {
        String(format: "%.1f m", value)
    }

    /// "62%"
    static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    /// "24:13" or "1:05:09"
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// "3h 12m", "45m", or "Under 1m"
    static func listeningTime(_ seconds: Double) -> String {
        let minutesTotal = Int(seconds / 60)
        guard minutesTotal > 0 else { return seconds > 0 ? "Under 1m" : "0m" }
        let hours = minutesTotal / 60
        let minutes = minutesTotal % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    /// "Center", "L 40", "R 25"
    static func pan(_ value: Double) -> String {
        let amount = Int((abs(value) * 100).rounded())
        if amount == 0 { return "Center" }
        return value < 0 ? "L \(amount)" : "R \(amount)"
    }
}
