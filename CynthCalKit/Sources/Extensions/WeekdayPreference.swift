//
//  WeekdayPreference.swift
//
//  Created by cyan on 6/25/26.
//

import Foundation
import os.lock

/**
 Holds an app-level override for the first weekday of the solar calendar.

 `nil` means "follow the system" (the default), otherwise it must be a valid
 weekday index (1...7), where 1 is Sunday and 2 is Monday.

 This is the kit's only piece of mutable global state, so access is guarded by
 an unfair lock to remain safe under StrictConcurrency.
 */
public final class WeekdayPreference: Sendable {
  public static let shared = WeekdayPreference()

  // Mutable, but guarded by `lock`; declared unsafe because the compiler cannot
  // see that all access is synchronized.
  nonisolated(unsafe) private var _firstWeekday: Int?
  nonisolated(unsafe) private var lock = os_unfair_lock_s()

  public var firstWeekday: Int? {
    get {
      os_unfair_lock_lock(&lock)
      defer { os_unfair_lock_unlock(&lock) }
      return _firstWeekday
    }
    set {
      os_unfair_lock_lock(&lock)
      _firstWeekday = newValue
      os_unfair_lock_unlock(&lock)
    }
  }

  private init() {}
}
