//
//  WeatherManager.swift
//
//  Created by cyan on 6/27/26.
//

import AppKit
import CynthCalKit
import Foundation

/**
 A coarse weather condition derived from the WWO weather code returned by wttr.in.

 Each case carries the SF Symbol name and a tint color used to render the faded background icon.
 */
enum WeatherCondition: Sendable {
  case clear
  case cloudy
  case rain
  case snow
  case fog
  case thunderstorm

  /// The SF Symbol used for the faded background icon.
  var symbolName: String {
    switch self {
    case .clear: "sun.max.fill"
    case .cloudy: "cloud.fill"
    case .rain: "cloud.rain.fill"
    case .snow: "cloud.snow.fill"
    case .fog: "cloud.fog.fill"
    case .thunderstorm: "cloud.bolt.rain.fill"
    }
  }

  /// A subtle tint color for the background. Always shown at low opacity by the view.
  var tintColor: NSColor {
    switch self {
    case .clear: NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.36, alpha: 1) // warm yellow
    case .cloudy: NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.82, alpha: 1) // light gray-blue
    case .rain: NSColor(calibratedRed: 0.45, green: 0.62, blue: 0.78, alpha: 1) // slate blue
    case .snow: NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.98, alpha: 1) // cold white-blue
    case .fog: NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.82, alpha: 1) // pale gray
    case .thunderstorm: NSColor(calibratedRed: 0.55, green: 0.48, blue: 0.72, alpha: 1) // muted purple
    }
  }

  /// Maps a WWO weather code (from wttr.in) to a coarse condition, or nil if unknown.
  static func from(weatherCode: Int) -> Self? {
    // WWO code groups: https://www.worldweatheronline.com/weather-api/
    switch weatherCode {
    case 113: return .clear
    case 116, 119, 122, 143, 248, 260: // partly cloudy / cloudy / overcast (fog-ish handled below)
      // 143/248/260 are mist/fog; route them to fog
      if weatherCode == 143 || weatherCode == 248 || weatherCode == 260 {
        return .fog
      }
      return .cloudy
    case 176, 200, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 317, 350, 353, 356, 359, 362, 365, 392, 395:
      // 200/392/395 are thundery with rain — route to thunderstorm
      if weatherCode == 200 || weatherCode == 392 || weatherCode == 395 {
        return .thunderstorm
      }
      return .rain
    case 179, 227, 230, 320, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377:
      return .snow
    case 386, 389:
      return .thunderstorm
    default:
      return nil
    }
  }
}

extension Notification.Name {
  /// Posted when the current weather condition changes.
  static let weatherConditionDidChange = Notification.Name("weatherConditionDidChange")
}

/**
 Fetches and caches the current weather condition from wttr.in.

 Designed to fail silently: any network or parsing error leaves `currentCondition` unchanged
 (or nil), so the calendar simply shows no weather background instead of surfacing errors.
 */
@MainActor
final class WeatherManager {
  static let shared = WeatherManager()

  /// The most recently observed condition, or nil if none has been fetched yet.
  private(set) var currentCondition: WeatherCondition? {
    didSet {
      guard oldValue != currentCondition else {
        return
      }

      NotificationCenter.default.post(name: .weatherConditionDidChange, object: nil)
    }
  }

  private var hourlyTimer: Timer?
  private var observer: NSObjectProtocol?

  private init() {}

  deinit {
    hourlyTimer?.invalidate()
  }

  /// Starts the hourly refresh loop and performs an immediate fetch.
  func start() {
    guard hourlyTimer == nil else {
      return
    }

    hourlyTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
      Task { await self?.refresh() }
    }

    Task { await refresh() }
  }

  /// Stops the hourly refresh loop.
  func stop() {
    hourlyTimer?.invalidate()
    hourlyTimer = nil
  }

  // MARK: - Fetching

  /// Fetches the current weather for the configured city. Fails silently on any error.
  nonisolated func refresh() async {
    let city = await AppPreferences.Weather.city
    guard let city, !city.isEmpty else {
      return
    }

    guard let url = URL(string: "https://wttr.in/\(city.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? city)?format=j1") else {
      return Logger.log(.error, "Failed to build wttr.in URL for city: \(city)")
    }

    guard let (data, response) = try? await URLSession.shared.data(from: url) else {
      return Logger.log(.error, "Failed to reach wttr.in")
    }

    guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
      return Logger.log(.error, "wttr.in returned a non-200 status")
    }

    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let conditions = root["current_condition"] as? [[String: Any]],
          let first = conditions.first,
          let codeString = first["weatherCode"] as? String,
          let code = Int(codeString),
          let condition = WeatherCondition.from(weatherCode: code) else {
      return Logger.log(.error, "Failed to parse wttr.in response")
    }

    await MainActor.run {
      currentCondition = condition
    }
  }
}
