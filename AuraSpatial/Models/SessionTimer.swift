//
//  SessionTimer.swift
//  AuraSpatial
//
//  A running Focus or Sleep timer. Stored as a start date + duration (not
//  a ticking counter), so the remaining time is always exact.
//

import Foundation

struct SessionTimer: Equatable {
    let mode: SessionMode
    let duration: TimeInterval
    let startDate: Date

    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, endDate.timeIntervalSince(date))
    }

    /// 1.0 when just started, 0.0 when finished.
    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return remaining(at: date) / duration
    }
}
