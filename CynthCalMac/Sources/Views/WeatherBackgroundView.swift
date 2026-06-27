//
//  WeatherBackgroundView.swift
//
//  Created by cyan on 6/27/26.
//

import AppKit

/**
 A decorative background layered behind the calendar content (and above the popover material).

 It shows a full atmospheric background image reflecting the current weather condition.
 When the feature is disabled (or no condition is available) it is hidden entirely so the
 underlying vibrancy material shows through unchanged.
 */
final class WeatherBackgroundView: NSView {
  private let imageView = NSImageView()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    // Both this view and the image view must be transparent so the underlying
    // vibrancy material shows through; only the (faded) image content is drawn.
    wantsLayer = true
    layer?.backgroundColor = .clear
    isHidden = true // hidden by default until a condition is available

    // Use autoresizing instead of Auto Layout so this view never participates in the
    // container's intrinsic-size negotiation, which could collapse the whole panel.
    imageView.imageScaling = .scaleAxesIndependently
    imageView.imageAlignment = .alignCenter
    imageView.alphaValue = Constants.backgroundAlpha
    imageView.wantsLayer = true
    imageView.layer?.backgroundColor = .clear
    imageView.autoresizingMask = [.width, .height]
    imageView.frame = bounds

    addSubview(imageView)
  }

  override func layout() {
    super.layout()
    imageView.frame = bounds
  }

  /// Updates the displayed condition, or clears the background if nil.
  func update(condition: WeatherCondition?) {
    guard let condition else {
      imageView.image = nil
      return
    }

    imageView.image = NSImage(named: condition.backgroundImageName)
  }

  private enum Constants {
    /// Keep the background as a faint ambience, never overpowering the calendar content.
    static let backgroundAlpha: Double = 0.58
  }
}

private extension WeatherCondition {
  /// The asset catalog image name for this condition's atmospheric background.
  var backgroundImageName: String {
    switch self {
    case .clear: "weather-clear"
    case .cloudy: "weather-cloudy"
    case .rain: "weather-rain"
    case .snow: "weather-snow"
    case .fog: "weather-fog"
    case .thunderstorm: "weather-thunderstorm"
    }
  }
}
