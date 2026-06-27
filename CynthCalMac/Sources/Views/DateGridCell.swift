//
//  DateGridCell.swift
//  CynthCalMac
//
//  Created by cyan on 12/22/23.
//

import AppKit
import AppKitControls
import EventKit
import CynthCalKit

/**
 Grid cell that draws a day, including its solar date and lunar date and decorating views.

 Example: 22 初十
 */
final class DateGridCell: NSCollectionViewItem {
  static let reuseIdentifier = NSUserInterfaceItemIdentifier("DateGridCell")

  private var cellDate: Date?
  private var cellEvents = [EKCalendarItem]()
  private var mainInfo = ""
  private var cellAnniversaries = [Anniversary]()

  private var detailsTask: Task<Void, Never>?
  private weak var detailsPopover: NSPopover?

  /// Whether this cell is currently selected (single-click). Drives the accent background.
  private var isCellSelected = false
  /// Whether the mouse is currently hovering over this cell.
  private var isHovered = false
  /// Timestamp of the last click, used to distinguish single vs. double click.
  private var lastClickTime: TimeInterval = 0
  /// Whether a single-click selection is still pending a possible double-click upgrade.
  private var selectionPending = false

  private let containerView: CustomButton = {
    let button = CustomButton()
    button.setAccessibilityElement(true)
    button.setAccessibilityRole(.button)
    button.setAccessibilityHelp(Localized.UI.accessibilityClickToRevealDate)

    return button
  }()

  private let highlightView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.alphaValue = 0

    view.layer?.cornerRadius = AppDesign.cellCornerRadius
    view.layer?.cornerCurve = .continuous

    return view
  }()

  private let solarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.solarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let lunarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.lunarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let eventView: EventView = {
    let view = EventView()
    view.setAccessibilityHidden(true)

    return view
  }()

  private let focusRingView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.isHidden = true
    view.setAccessibilityHidden(true)

    view.layer?.borderWidth = Constants.focusRingBorderWidth
    view.layer?.cornerRadius = AppDesign.cellCornerRadius
    view.layer?.cornerCurve = .continuous

    return view
  }()

  private let holidayView: NSImageView = {
    let view = NSImageView(image: Constants.holidayViewImage)
    view.isHidden = true
    view.setAccessibilityHidden(true)

    return view
  }()

  private let anniversaryView: NSImageView = {
    let view = NSImageView(image: Constants.anniversaryViewImage)
    view.isHidden = true
    view.contentTintColor = Colors.systemOrange
    view.setAccessibilityHidden(true)

    return view
  }()
}

// MARK: - Life Cycle

extension DateGridCell {
  override func loadView() {
    // Required prior to macOS Sonoma
    view = NSView(frame: .zero)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    containerView.frame = view.bounds

    // Keep the highlight color in sync with the current state after layout
    updateHighlightForHoverOrSelection()
    focusRingView.layer?.borderColor = Colors.controlAccent.cgColor
  }
}

// MARK: - Updating

extension DateGridCell {
  func updateViews(
    cellDate: Date,
    cellEvents: [EKCalendarItem],
    monthDate: Date?,
    lunarInfo: LunarInfo?
  ) {
    self.cellDate = cellDate
    self.cellEvents = cellEvents

    let currentDate = Date.now
    let solarComponents = Calendar.solar.dateComponents([.year, .month, .day], from: cellDate)
    let lunarComponents = Calendar.lunar.dateComponents([.year, .month, .day], from: cellDate)
    let isLastDayOfYear = Calendar.lunar.isLastDayOfYear(from: cellDate)
    let isLeapLunarMonth = Calendar.lunar.isLeapMonth(from: cellDate)

    let solarMonthDay = solarComponents.fourDigitsMonthDay
    let lunarMonthDay = lunarComponents.fourDigitsMonthDay

    let holidayType = HolidayManager.default.typeOf(
      year: solarComponents.year ?? 0, // It's too broken to have year as nil
      monthDay: solarMonthDay
    )

    // Solar day label
    if let day = solarComponents.day {
      solarLabel.stringValue = String(day)
    } else {
      Logger.assertFail("Failed to get solar day from date: \(cellDate)")
    }

    // Lunar day label
    if let day = lunarComponents.day {
      if day == 1, let month = lunarComponents.month {
        // The Chinese character "月" will shift the layout slightly to the left,
        // add a "thin space" to make it optically centered.
        lunarLabel.stringValue = "\u{2009}" + AppLocalizer.chineseMonth(of: month - 1, isLeap: isLeapLunarMonth)
      } else {
        lunarLabel.stringValue = AppLocalizer.chineseDay(of: day - 1)
      }
    } else {
      Logger.assertFail("Failed to get lunar day from date: \(cellDate)")
    }

    // Prefer solar term over normal lunar day
    if let solarTerm = lunarInfo?.solarTerms[solarMonthDay] {
      lunarLabel.stringValue = AppLocalizer.solarTerm(of: solarTerm)
    }

    // Prefer lunar holiday over solar term
    if let lunarHoliday = AppLocalizer.lunarFestival(of: lunarMonthDay) {
      lunarLabel.stringValue = lunarHoliday
    }

    // Chinese New Year's Eve, the last day of the lunar year, not necessarily a certain date
    if isLastDayOfYear {
      lunarLabel.stringValue = Localized.Calendar.chineseNewYearsEve
    }

    // Show the focus ring only for today
    let isDateToday = Calendar.solar.isDate(cellDate, inSameDayAs: currentDate)
    focusRingView.isHidden = !isDateToday

    // Reload event dot views
    eventView.updateEvents(cellEvents)

    // Bookmark for holiday plans
    switch holidayType {
    case .none:
      holidayView.isHidden = true
      holidayView.contentTintColor = nil
    case .workday:
      holidayView.isHidden = false
      holidayView.contentTintColor = Colors.systemOrange
    case .holiday:
      holidayView.isHidden = false
      holidayView.contentTintColor = Colors.systemTeal
    }

    // Personal anniversaries matched by either lunar or solar month/day
    cellAnniversaries = AppPreferences.Calendar.anniversariesEnabled
      ? AnniversaryStore.shared.lunarAnniversaries(on: lunarMonthDay, isLeap: isLeapLunarMonth)
        + AnniversaryStore.shared.solarAnniversaries(on: solarMonthDay)
      : []
    anniversaryView.isHidden = cellAnniversaries.isEmpty

    self.mainInfo = {
      var components: [String] = []
      // E.g. [Holiday]
      if let holidayLabel = AppLocalizer.holidayLabel(of: holidayType) {
        components.append(holidayLabel)
      }

      // E.g. [Anniversary] 奶奶生日
      if !cellAnniversaries.isEmpty {
        components.append(cellAnniversaries.map(\.name).joined(separator: " · "))
      }

      // Formatted lunar date, e.g., 癸卯年冬月十五 (leading numbers are removed to be concise)
      let lunarDate = Constants.lunarDateFormatter.string(from: cellDate)
      components.append(lunarDate.removingLeadingDigits)

      // Date ruler, e.g., "(10 days ago)" when hovering over a cell
      if let daysBetween = Calendar.solar.daysBetween(from: currentDate, to: cellDate) {
        if daysBetween == 0 {
          components.append(Localized.Calendar.todayLabel)
        } else {
          let format = daysBetween > 0 ? Localized.Calendar.daysLaterFormat : Localized.Calendar.daysAgoFormat
          components.append(String.localizedStringWithFormat(format, abs(daysBetween)))
        }
      }

      return components.joined()
    }()

    let accessibleDetails = {
      let eventTitles = cellEvents.compactMap { $0.title }

      // Only the main info
      if eventTitles.isEmpty {
        return mainInfo
      }

      // Full version, each trailing line is an event title
      return [mainInfo, eventTitles.joined(separator: "\n")].joined(separator: "\n\n")
    }()

    // Combine all visually available information to get the accessibility label
    containerView.setAccessibilityLabel([
      solarLabel.stringValue,
      lunarLabel.stringValue,
      accessibleDetails,
    ].compactMap { $0 }.joined(separator: " "))
  }

  func updateOpacity(monthDate: Date?) {
    let currentDate = Date.now
    let cellDate = cellDate ?? currentDate

    let solarComponents = Calendar.solar.dateComponents([.month], from: cellDate)
    let isDateToday = Calendar.solar.isDate(cellDate, inSameDayAs: currentDate)

    if let monthDate, Calendar.solar.month(from: monthDate) == solarComponents.month {
      if Calendar.solar.isDateInWeekend(cellDate) && !isDateToday {
        solarLabel.alphaValue = AlphaLevels.secondary
      } else {
        solarLabel.alphaValue = AlphaLevels.primary
      }

      // Intentional, secondary alpha is used only for labels at weekends
      eventView.alphaValue = AlphaLevels.primary
    } else {
      solarLabel.alphaValue = AlphaLevels.tertiary
      eventView.alphaValue = AlphaLevels.tertiary
    }

    lunarLabel.alphaValue = solarLabel.alphaValue
    holidayView.alphaValue = eventView.alphaValue
    anniversaryView.alphaValue = eventView.alphaValue
  }

  @discardableResult
  func cancelHighlight() -> Bool {
    // Dismiss hover details; keep the selection highlight (if any) intact
    isHovered = false
    updateHighlightForHoverOrSelection()
    return dismissDetails()
  }
}

// MARK: - Private

private extension DateGridCell {
  enum Constants {
    static let solarFontSize: Double = FontSizes.regular
    static let lunarFontSize: Double = FontSizes.small
    static let eventViewHeight: Double = 10
    static let focusRingBorderWidth: Double = 2
    static let holidayViewImage: NSImage = .with(symbolName: Icons.bookmarkFill, pointSize: 9)
    static let anniversaryViewImage: NSImage = .with(symbolName: Icons.heartFill, pointSize: 9)
    static let lunarDateFormatter: DateFormatter = .lunarDate
  }

  func setUp() {
    view.addSubview(containerView)
    containerView.addAction { [weak self] in
      self?.handleClick()
    }

    containerView.onMouseHover = { [weak self] isHovered in
      self?.onMouseHover(isHovered)
    }

    highlightView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(highlightView)

    solarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(solarLabel)
    NSLayoutConstraint.activate([
      solarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      solarLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppDesign.cellRectInset),
    ])

    lunarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(lunarLabel)
    NSLayoutConstraint.activate([
      lunarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      lunarLabel.topAnchor.constraint(equalTo: solarLabel.bottomAnchor),
    ])

    eventView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(eventView)
    NSLayoutConstraint.activate([
      eventView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      eventView.topAnchor.constraint(equalTo: lunarLabel.bottomAnchor),
      eventView.heightAnchor.constraint(equalToConstant: Constants.eventViewHeight),
    ])

    focusRingView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(focusRingView)
    NSLayoutConstraint.activate([
      highlightView.topAnchor.constraint(equalTo: containerView.topAnchor),
      highlightView.bottomAnchor.constraint(equalTo: eventView.bottomAnchor, constant: AppDesign.cellRectInset),
      highlightView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

      // Here we need to make sure the highlight view is wider than both labels
      highlightView.widthAnchor.constraint(
        greaterThanOrEqualTo: solarLabel.widthAnchor,
        constant: Constants.focusRingBorderWidth + AppDesign.cellRectInset * 2
      ),
      highlightView.widthAnchor.constraint(
        greaterThanOrEqualTo: lunarLabel.widthAnchor,
        constant: Constants.focusRingBorderWidth + AppDesign.cellRectInset * 2
      ),

      // The focus ring has the same frame as the highlight view
      focusRingView.leadingAnchor.constraint(equalTo: highlightView.leadingAnchor),
      focusRingView.trailingAnchor.constraint(equalTo: highlightView.trailingAnchor),
      focusRingView.topAnchor.constraint(equalTo: highlightView.topAnchor),
      focusRingView.bottomAnchor.constraint(equalTo: highlightView.bottomAnchor),
    ])

    holidayView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(holidayView)
    NSLayoutConstraint.activate([
      holidayView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -3.5),
      holidayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -1.5),
      holidayView.widthAnchor.constraint(equalToConstant: holidayView.frame.width),
      holidayView.heightAnchor.constraint(equalToConstant: holidayView.frame.height),
    ])

    // Anniversary marker sits just to the left of the holiday marker
    anniversaryView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(anniversaryView)
    NSLayoutConstraint.activate([
      anniversaryView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: -3.5),
      anniversaryView.trailingAnchor.constraint(equalTo: holidayView.leadingAnchor, constant: 0.5),
      anniversaryView.widthAnchor.constraint(equalToConstant: anniversaryView.frame.width),
      anniversaryView.heightAnchor.constraint(equalToConstant: anniversaryView.frame.height),
    ])

    let longPressRecognizer = NSPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    longPressRecognizer.minimumPressDuration = 0.5
    view.addGestureRecognizer(longPressRecognizer)
  }

  func revealDateInCalendar() {
    guard let cellDate else {
      return Logger.assertFail("Missing cellDate to continue")
    }

    dismissDetails()
    (NSApp.delegate as? AppDelegate)?.openCalendar(targetDate: cellDate)
  }

  /// Distinguishes a single click (select) from a double click (reveal in Calendar).
  /// Uses the system-configured double-click interval as the threshold.
  func handleClick() {
    let now = Date.timeIntervalSinceReferenceDate
    let isDoubleClick = (now - lastClickTime) <= NSEvent.doubleClickInterval
    lastClickTime = now

    if isDoubleClick {
      // Cancel the pending single-click selection and reveal the date instead
      selectionPending = false
      revealDateInCalendar()
    } else {
      // Defer the selection slightly so a quick second click upgrades it to a reveal
      selectionPending = true
      let cellDate = cellDate
      DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval) { [weak self] in
        guard let self, self.selectionPending, self.cellDate == cellDate else {
          return
        }

        self.selectionPending = false
        DateGridViewSelection.shared.select(cell: self)
      }
    }
  }

  /// Marks this cell as selected, showing the accent background. Called by the selection tracker.
  func setSelected(_ selected: Bool) {
    isCellSelected = selected
    updateHighlightForHoverOrSelection()
  }

  @objc func onLongPress(_ recognizer: NSPressGestureRecognizer) {
    guard recognizer.state == .began, let cellDate else {
      return
    }

    NSHapticFeedbackManager.defaultPerformer.perform(
      .generic,
      performanceTime: .now
    )

    dismissDetails()
    (NSApp.delegate as? AppDelegate)?.countDaysBetween(targetDate: cellDate)
  }

  func onMouseHover(_ hovered: Bool) {
    isHovered = hovered
    updateHighlightForHoverOrSelection()
    dismissDetails()

    guard hovered else {
      return
    }

    let showDetails = {
      try await Task.sleep(for: .seconds(0.5))
      let popover = DateDetailsView.createPopover(
        title: self.mainInfo,
        anniversaries: self.cellAnniversaries.map(\.name),
        events: self.cellEvents,
        lineWidth: self.view.hairlineWidth
      )

      popover.show(
        relativeTo: self.containerView.bounds,
        of: self.containerView,
        preferredEdge: .maxY
      )

      if !AppPreferences.Accessibility.reduceMotion {
        popover.window?.fadeIn()
      }

      self.detailsPopover = popover
    }

    detailsTask = Task {
      try? await showDetails()
    }
  }

  @discardableResult
  func dismissDetails() -> Bool {
    let wasOpen = detailsPopover?.isShown == true
    detailsTask?.cancel()

    let closeDetails: @Sendable () -> Void = {
      Task { @MainActor in
        self.detailsPopover?.close()
        self.detailsPopover = nil
      }
    }

    if !AppPreferences.Accessibility.reduceMotion, let window = detailsPopover?.window {
      window.fadeOut(completion: closeDetails)
    } else {
      closeDetails()
    }

    return wasOpen
  }

  /// Updates the highlight view to reflect the current hover and selection state.
  ///
  /// Selection takes precedence: an accent-colored background is shown for the selected cell.
  /// Otherwise a neutral hover highlight is shown while the mouse is over the cell.
  func updateHighlightForHoverOrSelection() {
    if isCellSelected {
      highlightView.layerBackgroundColor = Colors.controlAccent.withAlphaComponent(0.2)
      highlightView.setAlphaValue(1)
    } else if isHovered {
      highlightView.layerBackgroundColor = .highlightedBackground
      highlightView.setAlphaValue(1)
    } else {
      highlightView.setAlphaValue(0)
    }
  }
}

/**
 Tracks the currently selected date grid cell so that clicking another cell moves
 the selection (and clears the previous cell's highlight).
 */
@MainActor
final class DateGridViewSelection {
  static let shared = DateGridViewSelection()

  private weak var selectedCell: DateGridCell?

  private init() {}

  /// Selects the given cell, deselecting the previously selected one.
  func select(cell: DateGridCell) {
    guard cell !== selectedCell else {
      return
    }

    selectedCell?.setSelected(false)
    cell.setSelected(true)
    selectedCell = cell
  }

  /// Clears any current selection, e.g. when the grid is reloaded.
  func clear() {
    selectedCell?.setSelected(false)
    selectedCell = nil
  }
}
