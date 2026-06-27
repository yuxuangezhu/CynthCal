//
//  NSFont+Extension.swift
//
//  Created by cyan on 12/21/23.
//

import AppKit

public extension NSFont {
  /// The default menu bar font size for monospaced digit icons.
  static let defaultMenuBarFontSize: Double = 13

  static func menuBarMonospacedDigitFont(ofSize fontSize: Double? = nil) -> NSFont {
    NSFont.monospacedDigitSystemFont(ofSize: fontSize ?? defaultMenuBarFontSize, weight: .regular)
  }

  static func mediumSystemFont(ofSize fontSize: Double) -> NSFont {
    .systemFont(ofSize: fontSize, weight: .medium)
  }
}
