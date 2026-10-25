import SwiftUI
import UIKit

/// 设计 token（Claude 定，2026-10-18）。
/// 换品牌：通常只改 `brandLight` / `brandDark` 两个色值；其余保持不动。
/// 界面只能引用这里和 Components.swift，不得在页面里写死颜色、阴影、渐变。
enum Tokens {
    // MARK: 品牌
    private static let brandLight = UIColor(red: 0.12, green: 0.44, blue: 0.36, alpha: 1)  // #1F6F5C
    private static let brandDark = UIColor(red: 0.42, green: 0.78, blue: 0.67, alpha: 1)   // #6BC7AB

    // MARK: 颜色（自动适配深色模式）
    static let accent = dynamic(light: brandLight, dark: brandDark)
    static let accentSoft = dynamic(
        light: UIColor(red: 0.90, green: 0.95, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.22, blue: 0.19, alpha: 1))
    static let onAccent = dynamic(light: .white, dark: UIColor(red: 0.05, green: 0.12, blue: 0.10, alpha: 1))

    static let background = dynamic(
        light: UIColor(red: 0.965, green: 0.961, blue: 0.949, alpha: 1),  // #F6F5F2 暖灰白
        dark: UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
    static let surface = dynamic(
        light: .white,
        dark: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1))
    static let foreground = Color(uiColor: .label)
    static let secondary = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)

    static let success = dynamic(
        light: UIColor(red: 0.18, green: 0.49, blue: 0.31, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.80, blue: 0.56, alpha: 1))
    static let warning = dynamic(
        light: UIColor(red: 0.70, green: 0.42, blue: 0.00, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.72, blue: 0.30, alpha: 1))
    static let danger = dynamic(
        light: UIColor(red: 0.82, green: 0.24, blue: 0.24, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.47, blue: 0.45, alpha: 1))

    // MARK: 字体（跟随动态字体）
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let caption = Font.footnote
    static let number = Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()

    // MARK: 间距 / 圆角 / 尺寸
    static let compactSpacing: CGFloat = 8
    static let spacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let padding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let radius: CGFloat = 16
    static let smallRadius: CGFloat = 10
    static let buttonHeight: CGFloat = 52
    static let previewHeight: CGFloat = 280
    static let maxContentWidth: CGFloat = 560  // iPad 上内容不铺满

    // MARK: 阴影（只给卡片用，极轻）
    static let cardShadow = Color.black.opacity(0.04)

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
