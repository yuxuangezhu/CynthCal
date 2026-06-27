//
//  Anniversary.swift
//
//  Created by cyan on 6/26/26.
//

import Foundation

/// Which calendar an anniversary recurs by.
public enum AnniversaryCalendar: String, Codable, Sendable {
  case lunar
  case solar
}

/**
 A personal anniversary or birthday.

 Lunar anniversaries recur by the Chinese calendar (the solar date shifts each year),
 solar anniversaries recur by the Gregorian calendar.
 */
public struct Anniversary: Codable, Identifiable, Sendable, Hashable {
  public let id: UUID
  public var name: String
  public var calendar: AnniversaryCalendar

  // Lunar fields (used when `calendar == .lunar`)
  public var lunarMonth: Int
  public var lunarDay: Int
  public var isLeapMonth: Bool

  // Solar fields (used when `calendar == .solar`)
  public var solarMonth: Int
  public var solarDay: Int

  public var recurring: Bool
  public var lunarYear: Int?

  public init(
    id: UUID = UUID(),
    name: String,
    calendar: AnniversaryCalendar = .lunar,
    lunarMonth: Int = 1,
    lunarDay: Int = 1,
    isLeapMonth: Bool = false,
    solarMonth: Int = 1,
    solarDay: Int = 1,
    recurring: Bool = true,
    lunarYear: Int? = nil
  ) {
    self.id = id
    self.name = name
    self.calendar = calendar
    self.lunarMonth = lunarMonth
    self.lunarDay = lunarDay
    self.isLeapMonth = isLeapMonth
    self.solarMonth = solarMonth
    self.solarDay = solarDay
    self.recurring = recurring
    self.lunarYear = lunarYear
  }

  /// Four-digit "MMDD" key for the active calendar, matching `DateComponents.fourDigitsMonthDay`.
  public var monthDay: String {
    switch calendar {
    case .lunar:
      return String(format: "%02d%02d", lunarMonth, lunarDay)
    case .solar:
      return String(format: "%02d%02d", solarMonth, solarDay)
    }
  }

  // MARK: - Decoding (backward compatible)

  /// Custom decoding so that legacy data (lunar-only, pre-solar-support) still loads:
  /// a missing `calendar` falls back to `.lunar`, missing solar fields fall back to 1.
  private enum CodingKeys: String, CodingKey {
    case id, name, calendar, lunarMonth, lunarDay, isLeapMonth, solarMonth, solarDay, recurring, lunarYear
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    name = try c.decode(String.self, forKey: .name)
    calendar = try c.decodeIfPresent(AnniversaryCalendar.self, forKey: .calendar) ?? .lunar
    lunarMonth = try c.decode(Int.self, forKey: .lunarMonth)
    lunarDay = try c.decode(Int.self, forKey: .lunarDay)
    isLeapMonth = try c.decodeIfPresent(Bool.self, forKey: .isLeapMonth) ?? false
    solarMonth = try c.decodeIfPresent(Int.self, forKey: .solarMonth) ?? 1
    solarDay = try c.decodeIfPresent(Int.self, forKey: .solarDay) ?? 1
    recurring = try c.decodeIfPresent(Bool.self, forKey: .recurring) ?? true
    lunarYear = try c.decodeIfPresent(Int.self, forKey: .lunarYear)
  }
}
