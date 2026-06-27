//
//  DateRefreshTimer.swift
//  CynthCalMac
//
//  Created by cyan on 6/4/25.
//

import Foundation

/**
 A refresh timer that updates at intervals matching the granularity of a date format string.

 Automatically determines update frequency based on whether the format includes seconds, minutes, or hours,
 and schedules updates aligned to natural time boundaries (e.g., on the minute or hour).

 Assign a `dateFormat` string to start the timer. Set `dateFormat` to `nil` to stop it.
 */
final class DateRefreshTimer {
  var dateFormat: String? {
    didSet {
      stopTicking()
      startTicking()
    }
  }

  deinit {
    stopTicking()
  }

  init(onTick: @escaping (() -> Void)) {
    self.onTick = onTick
  }

  private var timer: Timer?
  private var onTick: (() -> Void)
}

// MARK: - Private

private extension DateRefreshTimer {
  func startTicking() {
    guard let dateFormat else {
      return
    }

    guard let granularity = Granularity.from(dateFormat: dateFormat) else {
      return
    }

    // Update immediately so the icon reflects the current value without waiting for the first tick
    onTick()
    scheduleNextTick(granularity: granularity)
  }

  func stopTicking() {
    timer?.invalidate()
    timer = nil
  }

  /// Schedules a single non-repeating tick aligned to the next natural boundary
  /// (e.g., the next whole second). Re-aligning on every tick prevents drift from
  /// accumulating, which otherwise causes the displayed time to stutter or lag by a second.
  func scheduleNextTick(granularity: Granularity) {
    guard let fireDate = granularity.nextFireDate else {
      return
    }

    timer = Timer(
      fireAt: fireDate,
      interval: 0, // non-repeating; we reschedule manually on each tick
      target: self,
      selector: #selector(handleTick),
      userInfo: granularity,
      repeats: false
    )

    if let timer = timer {
      // Allow the system to coalesce within a small window to reduce CPU load,
      // without affecting the displayed accuracy since we always re-align to the boundary
      timer.tolerance = granularity.tolerance
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  @objc func handleTick(_ timer: Timer) {
    onTick()

    guard let granularity = timer.userInfo as? Granularity else {
      return
    }

    scheduleNextTick(granularity: granularity)
  }
}

private enum Granularity: CaseIterable {
  case second
  case minute
  case hour

  // Matches dynamic expressions like {{expr}}, which may contain quotes that corrupt ICU parsing
  private static let dynamicExpressionPattern = /\{\{.*?\}\}/

  static func from(dateFormat: String) -> Self? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX") // For stable granularity detection

    // Strip {{expr}} blocks before probing the granularity, otherwise quotes inside the
    // expression are treated as ICU literal quotes and swallow the trailing date/time fields
    // (e.g. `HH:mm:ss`), causing the refresh frequency to be misdetected.
    let sanitizedFormat = dateFormat.replacing(dynamicExpressionPattern, with: "")
    formatter.dateFormat = sanitizedFormat

    let now = Date.now
    let text = formatter.string(from: now)

    // Find out the first granularity that produces different formatted dates
    let granularity = Self.allCases.first {
      let later = now.addingTimeInterval($0.tickInterval)
      return formatter.string(from: later) != text
    }

    if dateFormat.firstMatch(of: dynamicExpressionPattern) != nil {
      // Update at least hourly for dynamic expressions like {{expr}}
      return granularity ?? .hour
    }

    return granularity
  }

  /// Fixed duration of one step, used only to probe the format granularity
  /// (i.e., whether adding this much time changes the formatted string).
  var tickInterval: TimeInterval {
    switch self {
    case .second: return 1
    case .minute: return 60
    case .hour: return 3600
    }
  }

  /// How much slack the system is allowed when firing a tick. Since every tick is
  /// re-aligned to a natural boundary, this affects only efficiency, not accuracy.
  var tolerance: TimeInterval {
    switch self {
    case .second: return 0.1
    case .minute: return 1
    case .hour: return 10
    }
  }

  var nextFireDate: Date? {
    Calendar.solar.nextDate(
      after: Date.now,
      matching: {
        switch self {
        case .second: return DateComponents(nanosecond: 0)
        case .minute: return DateComponents(second: 0)
        case .hour: return DateComponents(minute: 0, second: 0)
        }
      }(),
      matchingPolicy: .nextTime
    )
  }
}
