//
//  WeatherParticleLayer.swift
//
//  Created by cyan on 6/30/26.
//

import AppKit
import QuartzCore

/**
 A GPU-accelerated particle layer that animates weather effects on top of the static background:
 rain falling, snow drifting, clouds moving, lightning flashing, sun pulsing, fog flowing.

 Each call to `configure(for:)` swaps in the matching emitter cells; `stopAnimating()` tears
 everything down so the layer (and the popover that hosts it) consumes no CPU when hidden.
 */
final class WeatherParticleLayer: CAEmitterLayer {
  override init() {
    super.init()
    setUp()
  }

  override init(layer: Any) {
    super.init(layer: layer)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    // Emit from the whole rectangle so particles fill the entire panel, not just a line.
    // Particles spawn anywhere in bounds and drift in randomized directions.
    emitterShape = .rectangle
    emitterMode = .volume
    emitterSize = CGSize(width: 1, height: 1)
    birthRate = 0 // nothing until configured
  }

  // MARK: - Configuration

  /// Configures the particle effect for the given condition, or clears it when nil.
  func configure(for condition: WeatherCondition?) {
    stopAnimating()

    guard let condition else {
      return
    }

    switch condition {
    case .clear:
      configureClear(condition)
    case .cloudy:
      configureCloudy(condition)
    case .rain:
      configureRain(condition)
    case .snow:
      configureSnow(condition)
    case .fog:
      configureFog(condition)
    case .thunderstorm:
      configureThunderstorm(condition)
    }
  }

  /// Removes all emitter cells and flashes, returning the layer to an idle state.
  func stopAnimating() {
    emitterCells = nil
    birthRate = 0
    flashTimer?.invalidate()
    flashTimer = nil
    removeAllAnimations()
    // Remove any flash layer from a previous thunderstorm config
    sublayers?.filter { $0.name == Self.flashLayerName }.forEach { $0.removeFromSuperlayer() }
  }

  // MARK: - Per-condition emitters

  private func configureClear(_ condition: WeatherCondition) {
    // Soft sun glows drifting slowly downward, like scattered sunlight
    let cell = CAEmitterCell()
    cell.contents = Self.sunGlowImage(color: condition.tintColor)
    cell.birthRate = 1.5
    cell.lifetime = 30
    cell.velocity = 4
    cell.velocityRange = 3
    cell.emissionLongitude = -.pi / 2 // downward
    cell.emissionRange = .pi / 6
    cell.yAcceleration = -1
    cell.scale = 0.7
    cell.scaleRange = 0.4
    cell.alphaRange = 0.5
    cell.alphaSpeed = -0.02
    cell.spin = 0.1
    cell.spinRange = 0.8
    cell.alphaSpeed = -0.015
    cell.spin = 0.2
    cell.spinRange = 1

    emitterCells = [cell]
    birthRate = 1
  }

  private func configureCloudy(_ condition: WeatherCondition) {
    // Cloud shapes sinking very slowly downward
    let cell = CAEmitterCell()
    cell.contents = Self.cloudImage(color: .white.withAlphaComponent(0.4))
    cell.birthRate = 0.15
    cell.lifetime = 60
    cell.velocity = 1.5
    cell.velocityRange = 1
    cell.emissionLongitude = -.pi / 2 // downward
    cell.emissionRange = .pi / 8
    cell.yAcceleration = -0.5
    cell.scale = 0.7
    cell.scaleRange = 0.4
    cell.alphaRange = 0.2
    cell.alphaSpeed = -0.003

    emitterCells = [cell]
    birthRate = 1
  }

  private func configureRain(_ condition: WeatherCondition) {
    // Teardrop raindrops falling slowly downward
    let cell = CAEmitterCell()
    cell.contents = Self.raindropImage(color: condition.tintColor.withAlphaComponent(0.6))
    cell.birthRate = 12
    cell.lifetime = 12
    cell.velocity = 35
    cell.velocityRange = 15
    cell.emissionLongitude = -.pi / 2 // downward
    cell.emissionRange = .pi / 8 // nearly straight down with slight spread
    cell.yAcceleration = -15
    cell.scale = 0.35
    cell.scaleRange = 0.2
    cell.alphaRange = 0.3
    cell.spin = 0
    cell.spinRange = 0.3

    emitterCells = [cell]
    birthRate = 1
  }

  private func configureSnow(_ condition: WeatherCondition) {
    // Snowflakes drifting slowly downward with gentle sway
    let cell = CAEmitterCell()
    cell.contents = Self.snowflakeImage(color: .white.withAlphaComponent(0.75))
    cell.birthRate = 4
    cell.lifetime = 35
    cell.velocity = 6
    cell.velocityRange = 3
    cell.emissionLongitude = -.pi / 2 // downward
    cell.emissionRange = .pi / 6
    cell.yAcceleration = -1.5
    cell.scale = 0.55
    cell.scaleRange = 0.3
    cell.alphaRange = 0.4
    cell.spin = 0.3
    cell.spinRange = 1.2

    emitterCells = [cell]
    birthRate = 1
  }

  private func configureFog(_ condition: WeatherCondition) {
    // Very large, very faint cloud blobs sinking very slowly
    let cell = CAEmitterCell()
    cell.contents = Self.cloudImage(color: .white.withAlphaComponent(0.12))
    cell.birthRate = 0.1
    cell.lifetime = 80
    cell.velocity = 1
    cell.velocityRange = 0.5
    cell.emissionLongitude = -.pi / 2 // downward
    cell.emissionRange = .pi / 8
    cell.yAcceleration = -0.3
    cell.scale = 1.2
    cell.scaleRange = 0.3
    cell.alphaRange = 0.1
    cell.alphaSpeed = -0.0015

    emitterCells = [cell]
    birthRate = 1
  }

  private func configureThunderstorm(_ condition: WeatherCondition) {
    // Falling raindrops
    let rain = CAEmitterCell()
    rain.contents = Self.raindropImage(color: condition.tintColor.withAlphaComponent(0.6))
    rain.birthRate = 10
    rain.lifetime = 12
    rain.velocity = 35
    rain.velocityRange = 15
    rain.emissionLongitude = -.pi / 2 // downward
    rain.emissionRange = .pi / 8
    rain.yAcceleration = -15
    rain.scale = 0.6
    rain.scaleRange = 0.3
    rain.alphaRange = 0.3
    rain.spinRange = 0.3

    // Falling lightning bolts (decorative, smaller and rarer)
    let bolt = CAEmitterCell()
    bolt.contents = Self.boltImage(color: NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.5, alpha: 0.8))
    bolt.birthRate = 0.3
    bolt.lifetime = 8
    bolt.velocity = 30
    bolt.velocityRange = 10
    bolt.emissionLongitude = -.pi / 2 // downward
    bolt.emissionRange = .pi / 6
    bolt.yAcceleration = -20
    bolt.scale = 0.5
    bolt.scaleRange = 0.3
    bolt.alphaRange = 0.5
    bolt.alphaSpeed = -0.1

    emitterCells = [rain, bolt]
    birthRate = 1

    // Add a full-bleed flash layer that we animate on a timer
    let flash = CALayer()
    flash.name = Self.flashLayerName
    flash.backgroundColor = NSColor.white.withAlphaComponent(0.5).cgColor
    flash.opacity = 0
    addSublayer(flash)
    flash.frame = bounds

    scheduleLightning()
  }

  // MARK: - Lightning

  private var flashTimer: Timer?

  /// Schedules a random lightning flash every 5-15 seconds while thunderstorm is active.
  private func scheduleLightning() {
    flashTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 5...15), repeats: false) { [weak self] _ in
      self?.flashLightning()
    }
  }

  /// Plays a multi-flicker lightning flash, then schedules the next one.
  private func flashLightning() {
    guard let flash = sublayers?.first(where: { $0.name == Self.flashLayerName }) else {
      scheduleLightning()
      return
    }

    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = [0.0, 0.45, 0.1, 0.35, 0.0, 0.0]
    animation.keyTimes = [0, 0.05, 0.12, 0.2, 0.35, 1]
    animation.duration = 1.2
    flash.add(animation, forKey: "lightningFlash")

    scheduleLightning()
  }

  private static let flashLayerName = "lightningFlash"
}

// MARK: - Particle image generators
//
// Each particle is a clean SF Symbol filled with a vertical gradient so it reads as a
// solid, legible shape — no glow, no blur, no frosted effects.

private extension WeatherParticleLayer {
  /// Renders an SF Symbol filled with a subtle vertical gradient.
  static func gradientSymbol(name: String, pointSize: Double, color: NSColor) -> CGImage? {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
      return nil
    }

    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    guard let configured = symbol.withSymbolConfiguration(config) else {
      return nil
    }

    let size = configured.size
    let target = NSImage(size: size)
    target.lockFocus()

    // 1. Draw the symbol shape to establish the alpha mask
    configured.draw(in: NSRect(origin: .zero, size: size))

    // 2. Fill ONLY the existing shape pixels with a gradient (sourceAtop clips to the shape).
    //    Convert to sRGB first — colors like .white use a gray colorspace whose RGB
    //    components cannot be read directly, which would crash on component access.
    let base = color.usingColorSpace(.sRGB) ?? NSColor(red: 1, green: 1, blue: 1, alpha: color.alphaComponent)
    let lighter = NSColor(
      red: min(base.redComponent + 0.2, 1.0),
      green: min(base.greenComponent + 0.2, 1.0),
      blue: min(base.blueComponent + 0.2, 1.0),
      alpha: base.alphaComponent
    )
    let darker = base.withAlphaComponent(base.alphaComponent * 0.75)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.compositingOperation = .sourceAtop
    if let grad = NSGradient(starting: lighter, ending: darker) {
      grad.draw(in: NSRect(origin: .zero, size: size), angle: 90)
    } else {
      base.set()
      NSRect(origin: .zero, size: size).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    target.unlockFocus()
    return target.cgImage(forProposedRect: nil, context: nil, hints: nil)
  }

  /// A clean teardrop raindrop with a subtle gradient.
  static func raindropImage(color: NSColor) -> CGImage? {
    gradientSymbol(name: "drop.fill", pointSize: 9, color: color)
  }

  /// A clean snowflake with a subtle gradient.
  static func snowflakeImage(color: NSColor) -> CGImage? {
    gradientSymbol(name: "snowflake", pointSize: 16, color: color)
  }

  /// A clean cloud with a subtle gradient.
  static func cloudImage(color: NSColor) -> CGImage? {
    gradientSymbol(name: "cloud.fill", pointSize: 48, color: color)
  }

  /// A clean lightning bolt with a subtle gradient.
  static func boltImage(color: NSColor) -> CGImage? {
    gradientSymbol(name: "bolt.fill", pointSize: 20, color: color)
  }

  /// A soft radial sun glow — bright center fading to transparent, like scattered sunlight.
  static func sunGlowImage(color: NSColor) -> CGImage? {
    let size = 60.0
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let center = NSPoint(x: size / 2, y: size / 2)
    // Concentric circles from bright core to transparent edge
    for ratio in stride(from: 1.0, through: 0.0, by: -0.05) {
      let radius = (size / 2) * ratio
      let alpha = color.alphaComponent * pow(1 - ratio, 2) * 0.9
      color.withAlphaComponent(alpha).setFill()
      NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
    }
    image.unlockFocus()
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  }
}
