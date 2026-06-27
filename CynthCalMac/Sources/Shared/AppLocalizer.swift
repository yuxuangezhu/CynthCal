//
//  AppLocalizer.swift
//  CynthCalMac
//
//  Created by cyan on 12/28/23.
//

import Foundation

enum AppLocalizer {
  static func solarTerm(of index: Int) -> String {
    Localized.Calendar.solarTerms[index]
  }

  static func chineseMonth(of index: Int, isLeap: Bool) -> String {
    let nameOfMonth = Localized.Calendar.chineseMonths[index]
    return isLeap ? (Localized.Calendar.chineseLeapMonth + nameOfMonth) : nameOfMonth
  }

  static func chineseDay(of index: Int) -> String {
    Localized.Calendar.chineseDays[index]
  }

  static func lunarFestival(of key: String) -> String? {
    Localized.Calendar.lunarFestivals[key]
  }

  /// The single-character Earthly Branch for the given hour (0-23), e.g. 子 for hour 23 or 0.
  static func earthlyBranch(of hour: Int) -> String {
    Localized.Calendar.earthlyBranches[shichenIndex(of: hour)]
  }

  /// The full shichen name for the given hour (0-23), e.g. 子时 for hour 23 or 0.
  static func shichenName(of hour: Int) -> String {
    Localized.Calendar.shichenNames[shichenIndex(of: hour)]
  }

  /// Maps a 24h hour to a 0-11 shichen index: 23:00-00:59 → 子(0), 01:00-02:59 → 丑(1), etc.
  private static func shichenIndex(of hour: Int) -> Int {
    ((hour + 1) / 2) % 12
  }

  static func holidayLabel(of type: HolidayType?) -> String? {
    let middleDot = " · "

    switch type {
    case .none:
      return nil
    case .workday:
      return Localized.Calendar.workdayLabel + middleDot
    case .holiday:
      return Localized.Calendar.holidayLabel + middleDot
    }
  }
}
