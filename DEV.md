# CynthCal 的开发

> [!NOTE]
> 本仓库是 [cyan/LunarBar](https://github.com/LunarBar-app/LunarBar) 的 fork（CynthCal）。原作者 cyan 撰写了一篇完整的开发手记，记录了项目的设计思路与难点，详见：[原作 DEV.md](https://github.com/LunarBar-app/LunarBar/blob/main/DEV.md)。

## 核心原则

延续原项目的理念：**除非万不得已，尽可能地依赖系统行为**。每多一个自研计算，就会多一个出错的机会。本 fork 的新增功能（农历/公历纪念日、时辰干支、周首日等）同样遵循这一原则。

## 关键技术决策（继承自原项目）

- **农历转换**完全依赖 `Calendar(identifier: .chinese)`，不做任何经验性计算；`month` / `day` 经 `DateComponents` 取出后映射为「正月」「初一」等字符串。
- **干支**来自系统 `DateFormatter` 在中文 locale 下的输出（如 `2023年癸卯冬月十九`），不自行实现天干地支算法。
- **二十四节气**采用打表方式（200 年天文台数据，压缩至约 35KB 的 [data.json](./CynthCalKit/Sources/LunarCalendar/Resources/data.json)），因为公式计算几乎都无法 100% 正确。
- **日期格式化**使用 `setLocalizedDateFormatFromTemplate` 让系统按 locale 决定输出格式。
- **界面**基于 AppKit（而非 SwiftUI），以获得精细控制；采用 Modern Collection Views 的技巧。

## 沙盒与权限

CynthCal 是沙盒应用，通过 AppleScript 与系统日历交互，需要以下权限：

```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
<key>com.apple.security.personal-information.calendars</key>
<true/>
<key>com.apple.security.temporary-exception.apple-events</key>
<array>
  <string>com.apple.iCal</string>
</array>
```

以及 `NSCalendarsFullAccessUsageDescription`。

## 本地化

默认语言为英语，本地化为简体中文与繁体中文。使用 [string catalogs](https://developer.apple.com/videos/play/wwdc2023/10155/) 管理多语言文案。繁体转换参考 [OpenCC](https://github.com/BYVoid/OpenCC) 与 [Apple Localization Terms Glossary](https://applelocalization.com)。

## 更多背景

关于项目最初的开发动机、界面技术选型的完整讨论、本地化过程中的人工程校对细节等，请阅读原作者的完整手记：[LunarBar-app/LunarBar — DEV.md](https://github.com/LunarBar-app/LunarBar/blob/main/DEV.md)。
