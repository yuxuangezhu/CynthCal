//
//  ShichenTests.swift
//
//  Created by cyan on 6/26/26.
//

import XCTest
@testable import CynthCal

final class ShichenTests: XCTestCase {
  /// Verify the full 24-hour to 12-shichen mapping, including the 23/0 boundary (子).
  func testHourToShichenMapping() {
    // (hour, expectedEarthlyBranch, expectedShichenName)
    let expectations: [(Int, String, String)] = [
      (0, "子", "子时"),
      (1, "丑", "丑时"),
      (2, "丑", "丑时"),
      (3, "寅", "寅时"),
      (4, "寅", "寅时"),
      (5, "卯", "卯时"),
      (6, "卯", "卯时"),
      (7, "辰", "辰时"),
      (8, "辰", "辰时"),
      (9, "巳", "巳时"),
      (10, "巳", "巳时"),
      (11, "午", "午时"),
      (12, "午", "午时"),
      (13, "未", "未时"),
      (14, "未", "未时"),
      (15, "申", "申时"),
      (16, "申", "申时"),
      (17, "酉", "酉时"),
      (18, "酉", "酉时"),
      (19, "戌", "戌时"),
      (20, "戌", "戌时"),
      (21, "亥", "亥时"),
      (22, "亥", "亥时"),
      (23, "子", "子时"),
    ]

    for (hour, branch, name) in expectations {
      XCTAssertEqual(AppLocalizer.earthlyBranch(of: hour), branch, "hour \(hour) branch mismatch")
      XCTAssertEqual(AppLocalizer.shichenName(of: hour), name, "hour \(hour) name mismatch")
    }
  }
}
