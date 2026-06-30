//
//  AppMainVC.swift
//  CynthCalMac
//
//  Created by cyan on 12/21/23.
//

import AppKit
import CynthCalKit

/**
 The main view controller that manages all components.
 */
final class AppMainVC: NSViewController {
  // States
  var pinnedOnTop = false
  var monthDate = Date.now
  weak var popover: NSPopover?

  // Views
  private let scalableView = ScalableView()
  private let headerView = HeaderView()
  private let weekdayView = WeekdayView()
  private let dateGridView = DateGridView()
  private let weatherBackgroundView = WeatherBackgroundView()
  private var weatherObserver: NSObjectProtocol?

  deinit {
    if let weatherObserver {
      NotificationCenter.default.removeObserver(weatherObserver)
    }
  }

  // Factory function
  static func createPopover() -> NSPopover {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = desiredContentSize
    popover.animates = !AppPreferences.Accessibility.reduceMotion

    let contentVC = Self()
    contentVC.popover = popover
    popover.contentViewController = contentVC

    return popover
  }
}

// MARK: - Internal

extension AppMainVC {
  override func loadView() {
    // Required prior to macOS Sonoma
    view = NSView(frame: CGRect(origin: .zero, size: Self.desiredContentSize))
    view.addScalableView(scalableView, scale: AppPreferences.General.contentScale.rawValue)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setUp()
    observeKeyEvents()

    weatherObserver = NotificationCenter.default.addObserver(
      forName: .weatherConditionDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.updateWeatherBackground()
    }
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    applyMaterial(AppPreferences.Accessibility.popoverMaterial)

    updateAppearance()
    updateCalendar()
    updateWeatherBackground()

    // Proactively refresh weather so a freshly opened panel shows the latest condition
    if AppPreferences.Weather.enabled {
      Task { await WeatherManager.shared.refresh() }
    }
  }

  // MARK: - Updating

  func updateAppearance(_ appearance: Appearance = AppPreferences.General.appearance) {
    AppPreferences.General.appearance = appearance

    // Override both since in some contexts we don't have a window
    NSApp.appearance = appearance.resolved()
    view.window?.appearance = NSApp.appearance
  }

  func updateCalendar(targetDate: Date = .now) {
    Logger.log(.info, "Updating calendar to target date: \(targetDate)")
    monthDate = targetDate

    let solarYear = Calendar.solar.year(from: targetDate)
    let lunarInfo = LunarCalendar.default.info(of: solarYear)

    headerView.updateCalendar(date: targetDate)
    dateGridView.updateCalendar(date: targetDate, lunarInfo: lunarInfo)
  }

  func updateCalendar(moveBy offset: Int, unit: Calendar.Component) {
    guard let newDate = Calendar.solar.date(byAdding: unit, value: offset, to: monthDate) else {
      return Logger.assertFail("Failed to get date by adding \(offset) \(unit)")
    }

    Logger.log(.info, "Moving the calendar by \(offset) \(unit)")
    updateCalendar(targetDate: newDate)
  }

  func togglePinnedOnTop() {
    pinnedOnTop.toggle()
    popover?.behavior = pinnedOnTop ? .applicationDefined : .transient
  }

  /// Refreshes the weather background to match the current preference and condition.
  func updateWeatherBackground() {
    // Hidden entirely when the feature is off or no condition is available yet.
    // Hiding (rather than just clearing the image) keeps the underlying vibrancy material visible.
    let condition = AppPreferences.Weather.enabled ? WeatherManager.shared.currentCondition : nil
    weatherBackgroundView.isHidden = (condition == nil)
    weatherBackgroundView.update(condition: condition)
  }

  /// Stops the weather particle animations (called when the popover closes to save CPU).
  func stopWeatherAnimation() {
    weatherBackgroundView.stopAnimating()
  }
}

// MARK: - HeaderViewDelegate

extension AppMainVC: HeaderViewDelegate {
  // periphery:ignore:parameters sender
  func headerView(_ sender: HeaderView, moveTo date: Date) {
    updateCalendar(targetDate: date)
  }

  // periphery:ignore:parameters sender
  func headerView(_ sender: HeaderView, moveBy offset: Int) {
    updateCalendar(moveBy: offset, unit: .month)
  }

  // periphery:ignore:parameters sender
  func headerView(_ sender: HeaderView, showActionsMenu sourceView: NSView) {
    showActionsMenu(sourceView: sourceView)
  }
}

// MARK: - Private

private extension AppMainVC {
  enum Constants {
    static let headerViewHeight: Double = 40
    static let weekdayViewHeight: Double = 17
    static let dateGridViewMarginTop: Double = 10
  }

  @MainActor static var desiredContentSize: CGSize {
    let cellInset = AppDesign.cellRectInset * 2
    let contentMargin = AppDesign.contentMargin * 2
    let contentScale = AppPreferences.General.contentScale.rawValue

    return CGSize(
      width: 240 * contentScale + cellInset * Double(Calendar.solar.numberOfDaysInWeek) + contentMargin,
      height: 320 * contentScale + cellInset * Double(Calendar.solar.numberOfRowsInMonth) + contentMargin
    )
  }

  func setUp() {
    let view = scalableView.container
    let margin = AppDesign.contentMargin

    headerView.delegate = self
    headerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(headerView)
    NSLayoutConstraint.activate([
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
      headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
      headerView.heightAnchor.constraint(equalToConstant: Constants.headerViewHeight),
    ])

    weekdayView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(weekdayView)
    NSLayoutConstraint.activate([
      weekdayView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
      weekdayView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      weekdayView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
      weekdayView.heightAnchor.constraint(equalToConstant: Constants.weekdayViewHeight),
    ])

    dateGridView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(dateGridView)
    NSLayoutConstraint.activate([
      dateGridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
      dateGridView.topAnchor.constraint(equalTo: weekdayView.bottomAnchor, constant: Constants.dateGridViewMarginTop),
      dateGridView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
      dateGridView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
    ])

    // Weather background sits behind everything, filling the whole container.
    // Use autoresizing (not Auto Layout) so it never participates in the container's
    // intrinsic size negotiation, which could collapse the whole panel.
    weatherBackgroundView.frame = view.bounds
    weatherBackgroundView.autoresizingMask = [.width, .height]
    view.addSubview(weatherBackgroundView, positioned: .below, relativeTo: headerView)
    updateWeatherBackground()
  }

  func observeKeyEvents() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.view.window?.isKeyWindow == true else {
        return event
      }

      switch event.keyCode {
      case .kVK_Space:
        // Space key is occupied by keyboard navigation
        if NSApp.isFullKeyboardAccessEnabled {
          return event
        }

        self.updateCalendar()
        self.headerView.showClickEffect(for: .actions)
        return nil
      case .kVK_Escape:
        if self.dateGridView.cancelHighlight() {
          return nil
        }

        return event
      case .kVK_LeftArrow:
        self.updateCalendar(moveBy: -1, unit: .month)
        self.headerView.showClickEffect(for: .previous)
        return nil
      case .kVK_RightArrow:
        self.updateCalendar(moveBy: 1, unit: .month)
        self.headerView.showClickEffect(for: .next)
        return nil
      case .kVK_UpArrow:
        self.updateCalendar(moveBy: -1, unit: .year)
        return nil
      case .kVK_DownArrow:
        self.updateCalendar(moveBy: 1, unit: .year)
        return nil
      case .kVK_ANSI_P:
        self.togglePinnedOnTop()
        return nil
      default:
        return event
      }
    }
  }
}
