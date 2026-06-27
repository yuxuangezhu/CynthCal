//
//  AnniversaryStore.swift
//
//  Created by cyan on 6/26/26.
//

import Foundation

/**
 Loads, persists, and queries personal lunar anniversaries.

 Data is kept in a single JSON file under the user's Documents directory, mirroring the
 location used by `HolidayManager`'s user-defined holidays.
 */
@MainActor
public final class AnniversaryStore {
  public static let shared = AnniversaryStore()

  /// All anniversaries, in the order they were added.
  public private(set) var anniversaries: [Anniversary] = []

  private init() {
    load()
  }

  // MARK: - Mutations

  public func add(_ anniversary: Anniversary) {
    anniversaries.append(anniversary)
    persist()
  }

  public func update(_ anniversary: Anniversary) {
    guard let index = anniversaries.firstIndex(where: { $0.id == anniversary.id }) else {
      return Logger.assertFail("Anniversary not found for update: \(anniversary.id)")
    }

    anniversaries[index] = anniversary
    persist()
  }

  public func remove(id: UUID) {
    anniversaries.removeAll { $0.id == id }
    persist()
  }

  // MARK: - Query

  /// Lunar anniversaries matching a lunar "MMDD" key and leap-month flag.
  public func lunarAnniversaries(on monthDay: String, isLeap: Bool) -> [Anniversary] {
    anniversaries.filter {
      $0.calendar == .lunar && $0.monthDay == monthDay && $0.isLeapMonth == isLeap
    }
  }

  /// Solar anniversaries matching a solar "MMDD" key.
  public func solarAnniversaries(on monthDay: String) -> [Anniversary] {
    anniversaries.filter {
      $0.calendar == .solar && $0.monthDay == monthDay
    }
  }

  // MARK: - Persistence

  private func load() {
    guard let data = try? Data(contentsOf: Constants.fileURL) else {
      return // First launch, no file yet
    }

    do {
      anniversaries = try Constants.decoder.decode([Anniversary].self, from: data)
    } catch {
      Logger.log(.error, "Failed to decode anniversaries: \(error.localizedDescription)")
    }
  }

  private func persist() {
    do {
      try FileManager.default.createDirectory(
        at: Constants.directoryURL,
        withIntermediateDirectories: true
      )

      let data = try Constants.encoder.encode(anniversaries)
      try data.write(to: Constants.fileURL, options: .atomic)
    } catch {
      Logger.log(.error, "Failed to persist anniversaries: \(error.localizedDescription)")
    }
  }

  private enum Constants {
    static let directoryURL = URL.documentsDirectory.appending(
      path: "LunarBar",
      directoryHint: .isDirectory
    )

    static let fileURL = directoryURL.appending(
      path: "anniversaries.json",
      directoryHint: .notDirectory
    )

    static let encoder = {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      return encoder
    }()

    static let decoder = JSONDecoder()
  }
}
