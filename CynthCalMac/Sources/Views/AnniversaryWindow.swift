//
//  AnniversaryWindow.swift
//
//  Created by cyan on 6/26/26.
//

import AppKit
import CynthCalKit
import SwiftUI

/**
 A standalone window for managing personal lunar anniversaries.
 */
@MainActor
enum AnniversaryWindow {
  private static weak var window: NSWindow?

  /// Shows the management window, creating it if needed (single instance).
  static func show() {
    if let window, window.isVisible {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let hostingController = NSHostingController(rootView: AnniversaryListView())
    let window = NSWindow(contentViewController: hostingController)
    window.title = Localized.UI.menuTitleAnniversaries
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()

    self.window = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: - List

private struct AnniversaryListView: View {
  @State private var anniversaries: [Anniversary] = AnniversaryStore.shared.anniversaries
  @State private var editing: Anniversary?
  @State private var isAdding = false

  var body: some View {
    VStack(spacing: 0) {
      if anniversaries.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: Icons.heartFill)
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
          Text(Localized.UI.messageNoAnniversaries)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
      } else {
        List {
          ForEach(anniversaries) { anniversary in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(anniversary.name)
                  .font(.headline)
                Text(displayString(for: anniversary))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Button(Localized.UI.buttonEdit) {
                editing = anniversary
              }
            }
            .padding(.vertical, 4)
          }
          .onDelete { indexSet in
            for index in indexSet {
              let id = anniversaries[index].id
              AnniversaryStore.shared.remove(id: id)
            }
            anniversaries = AnniversaryStore.shared.anniversaries
          }
        }
      }

      Divider()

      HStack {
        Button {
          isAdding = true
        } label: {
          Label(Localized.UI.buttonAdd, systemImage: "plus")
        }
        .keyboardShortcut(.defaultAction)

        Spacer()
      }
      .padding(12)
    }
    .frame(minWidth: 360, minHeight: 320)
    .sheet(isPresented: $isAdding) {
      AnniversaryEditor(anniversary: nil) { newAnniversary in
        AnniversaryStore.shared.add(newAnniversary)
        anniversaries = AnniversaryStore.shared.anniversaries
      }
    }
    .sheet(item: $editing) { anniversary in
      AnniversaryEditor(anniversary: anniversary) { updated in
        AnniversaryStore.shared.update(updated)
        anniversaries = AnniversaryStore.shared.anniversaries
      }
    }
  }

  private func displayString(for anniversary: Anniversary) -> String {
    var parts: [String] = []

    switch anniversary.calendar {
    case .lunar:
      let monthName = AppLocalizer.chineseMonth(of: anniversary.lunarMonth - 1, isLeap: anniversary.isLeapMonth)
      let dayName = AppLocalizer.chineseDay(of: anniversary.lunarDay - 1)
      parts.append("\(monthName)\(dayName)")
    case .solar:
      parts.append(String(format: "%02d-%02d", anniversary.solarMonth, anniversary.solarDay))
    }

    if anniversary.recurring {
      parts.append(Localized.UI.labelRecurring)
    } else if let year = anniversary.lunarYear {
      parts.append(String(format: Localized.UI.labelOneTimeFormat, year))
    }

    return parts.joined(separator: " · ")
  }
}

// MARK: - Editor

private struct AnniversaryEditor: View {
  @Environment(\.dismiss)
  private var dismiss

  @State private var name: String
  @State private var calendar: AnniversaryCalendar
  @State private var lunarMonth: Int
  @State private var lunarDay: Int
  @State private var isLeapMonth: Bool
  @State private var solarMonth: Int
  @State private var solarDay: Int
  @State private var recurring: Bool

  private let original: Anniversary?
  private let onCommit: (Anniversary) -> Void

  init(anniversary: Anniversary?, onCommit: @escaping (Anniversary) -> Void) {
    self.original = anniversary
    self.onCommit = onCommit

    _name = State(initialValue: anniversary?.name ?? "")
    _calendar = State(initialValue: anniversary?.calendar ?? .lunar)
    _lunarMonth = State(initialValue: anniversary?.lunarMonth ?? 1)
    _lunarDay = State(initialValue: anniversary?.lunarDay ?? 1)
    _isLeapMonth = State(initialValue: anniversary?.isLeapMonth ?? false)
    _solarMonth = State(initialValue: anniversary?.solarMonth ?? 1)
    _solarDay = State(initialValue: anniversary?.solarDay ?? 1)
    _recurring = State(initialValue: anniversary?.recurring ?? true)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      TextField(Localized.UI.placeholderAnniversaryName, text: $name)
        .textFieldStyle(.roundedBorder)

      Picker(Localized.UI.labelCalendarType, selection: $calendar) {
        Text(Localized.UI.labelLunar).tag(AnniversaryCalendar.lunar)
        Text(Localized.UI.labelSolar).tag(AnniversaryCalendar.solar)
      }
      .pickerStyle(.segmented)

      HStack {
        switch calendar {
        case .lunar:
          Picker(Localized.UI.labelMonth, selection: $lunarMonth) {
            ForEach(1...12, id: \.self) { month in
              Text(AppLocalizer.chineseMonth(of: month - 1, isLeap: false)).tag(month)
            }
          }

          Picker(Localized.UI.labelDay, selection: $lunarDay) {
            ForEach(1...30, id: \.self) { day in
              Text(AppLocalizer.chineseDay(of: day - 1)).tag(day)
            }
          }
        case .solar:
          Picker(Localized.UI.labelMonth, selection: $solarMonth) {
            ForEach(1...12, id: \.self) { month in
              Text("\(month)").tag(month)
            }
          }

          Picker(Localized.UI.labelDay, selection: $solarDay) {
            ForEach(1...31, id: \.self) { day in
              Text("\(day)").tag(day)
            }
          }
        }
      }

      if calendar == .lunar {
        Toggle(Localized.UI.labelLeapMonth, isOn: $isLeapMonth)
      }
      Toggle(Localized.UI.labelRecurring, isOn: $recurring)

      HStack {
        Spacer()
        Button(Localized.General.cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button(Localized.UI.buttonSave) { commit() }
          .keyboardShortcut(.defaultAction)
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(20)
    .frame(width: 340)
  }

  private func commit() {
    let anniversary = Anniversary(
      id: original?.id ?? UUID(),
      name: name.trimmingCharacters(in: .whitespaces),
      calendar: calendar,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      isLeapMonth: isLeapMonth,
      solarMonth: solarMonth,
      solarDay: solarDay,
      recurring: recurring,
      lunarYear: original?.lunarYear
    )

    onCommit(anniversary)
    dismiss()
  }
}
