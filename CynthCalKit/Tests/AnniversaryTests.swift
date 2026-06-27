//
//  AnniversaryTests.swift
//
//  Created by cyan on 6/26/26.
//

import CynthCalKit
import XCTest

final class AnniversaryTests: XCTestCase {
  func testLunarMonthDayFormat() {
    let anniversary = Anniversary(name: "Test", calendar: .lunar, lunarMonth: 1, lunarDay: 1)
    XCTAssertEqual(anniversary.monthDay, "0101")

    let anniversary2 = Anniversary(name: "Test", calendar: .lunar, lunarMonth: 8, lunarDay: 15)
    XCTAssertEqual(anniversary2.monthDay, "0815")

    let anniversary3 = Anniversary(name: "Test", calendar: .lunar, lunarMonth: 12, lunarDay: 30)
    XCTAssertEqual(anniversary3.monthDay, "1230")
  }

  func testSolarMonthDayFormat() {
    let anniversary = Anniversary(name: "Test", calendar: .solar, solarMonth: 2, solarDay: 14)
    XCTAssertEqual(anniversary.monthDay, "0214")

    let anniversary2 = Anniversary(name: "Test", calendar: .solar, solarMonth: 12, solarDay: 25)
    XCTAssertEqual(anniversary2.monthDay, "1225")
  }

  func testCodableRoundTrip() throws {
    let original = Anniversary(
      name: "奶奶生日",
      calendar: .lunar,
      lunarMonth: 5,
      lunarDay: 12,
      isLeapMonth: true,
      solarMonth: 6,
      solarDay: 18,
      recurring: false,
      lunarYear: 2024
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Anniversary.self, from: encoded)

    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.name, original.name)
    XCTAssertEqual(decoded.calendar, original.calendar)
    XCTAssertEqual(decoded.lunarMonth, original.lunarMonth)
    XCTAssertEqual(decoded.lunarDay, original.lunarDay)
    XCTAssertEqual(decoded.isLeapMonth, original.isLeapMonth)
    XCTAssertEqual(decoded.solarMonth, original.solarMonth)
    XCTAssertEqual(decoded.solarDay, original.solarDay)
    XCTAssertEqual(decoded.recurring, original.recurring)
    XCTAssertEqual(decoded.lunarYear, original.lunarYear)
  }

  func testSolarCodableRoundTrip() throws {
    let original = Anniversary(
      name: "Wedding",
      calendar: .solar,
      solarMonth: 10,
      solarDay: 1,
      recurring: true
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Anniversary.self, from: encoded)

    XCTAssertEqual(decoded.calendar, .solar)
    XCTAssertEqual(decoded.solarMonth, 10)
    XCTAssertEqual(decoded.solarDay, 1)
    XCTAssertEqual(decoded.monthDay, "1001")
  }

  /// Legacy data (created before solar support) must still load, defaulting to lunar.
  func testBackwardCompatWithLegacyJSON() throws {
    let legacyJSON = #"""
    [{"id":"00000000-0000-0000-0000-000000000001","name":"奶奶生日","lunarMonth":5,"lunarDay":12,"isLeapMonth":true,"recurring":true}]
    """#.data(using: .utf8) ?? Data()

    let decoded = try JSONDecoder().decode([Anniversary].self, from: legacyJSON)
    XCTAssertEqual(decoded.count, 1)
    XCTAssertEqual(decoded[0].name, "奶奶生日")
    XCTAssertEqual(decoded[0].calendar, .lunar)
    XCTAssertEqual(decoded[0].lunarMonth, 5)
    XCTAssertEqual(decoded[0].lunarDay, 12)
    XCTAssertTrue(decoded[0].isLeapMonth)
    XCTAssertTrue(decoded[0].recurring)
  }
}
