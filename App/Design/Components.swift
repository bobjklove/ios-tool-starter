import SwiftUI

// 通用视觉组件（Claude 定，2026-10-18）。页面只组合这些组件，不另写样式。
// Codex 只负责接线，不改本文件的样式参数。

/// 主按钮：整宽、品牌色底。每屏最多一个。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.headline)
            .frame(maxWidth: .infinity, minHeight: Tokens.buttonHeight)
            .foregroundStyle(Tokens.onAccent)
            .background(Tokens.accent, in: RoundedRectangle(cornerRadius: Tokens.radius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 次按钮：整宽、浅品牌色底、品牌色字。
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.headline)
            .frame(maxWidth: .infinity, minHeight: Tokens.buttonHeight)
            .foregroundStyle(Tokens.accent)
            .background(Tokens.accentSoft, in: RoundedRectangle(cornerRadius: Tokens.radius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// 文字按钮：次要操作（恢复购买、恢复草稿等）。
struct TextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.body)
            .foregroundStyle(Tokens.accent)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: PrimaryButtonStyle { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: SecondaryButtonStyle { .init() } }
extension ButtonStyle where Self == TextLinkButtonStyle { static var textLink: TextLinkButtonStyle { .init() } }

/// 卡片：白底圆角，内容分组用。
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing) { content }
            .padding(Tokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radius, style: .continuous))
            .shadow(color: Tokens.cardShadow, radius: 8, y: 2)
    }
}

/// 分区标题：卡片上方的小标题。
struct SectionHeader: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(Tokens.caption.weight(.semibold))
            .foregroundStyle(Tokens.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

/// 数值行：左标签、右数值（尺寸、剩余次数等）。
struct ValueRow<Trailing: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(label).font(Tokens.body)
            Spacer(minLength: Tokens.spacing)
            trailing
        }
    }
}

/// 状态提示条：导出成功 / 出错 / 免费次数等一行提示。
struct StatusBanner: View {
    enum Kind { case info, success, warning, error }
    let text: String
    var kind: Kind = .info
    private var color: Color {
        switch kind {
        case .info: Tokens.accent
        case .success: Tokens.success
        case .warning: Tokens.warning
        case .error: Tokens.danger
        }
    }
    private var symbol: String {
        switch kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
    var body: some View {
        Label { Text(verbatim: text) } icon: { Image(systemName: symbol) }
            .font(Tokens.caption)
            .foregroundStyle(color)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: Tokens.smallRadius, style: .continuous))
    }
}

/// 空状态：还没选内容时的居中引导。
struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var body: some View {
        VStack(spacing: Tokens.compactSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Tokens.accent)
                .padding(.bottom, Tokens.compactSpacing)
            Text(title).font(Tokens.title)
            Text(message).font(Tokens.body).foregroundStyle(Tokens.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// 内购权益行：买断页列出「解锁后得到什么」。
struct BenefitRow: View {
    let symbol: String
    let text: LocalizedStringKey
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Tokens.accent).frame(width: 24)
            Text(text).font(Tokens.body)
        }
    }
}

/// 页面容器：统一背景、边距、iPad 最大宽度。
struct ScreenContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.sectionSpacing) { content }
                .padding(Tokens.padding)
                .frame(maxWidth: Tokens.maxContentWidth)
                .frame(maxWidth: .infinity)
        }
        .background(Tokens.background.ignoresSafeArea())
    }
}

/// 底部操作栏：放每屏唯一的主按钮，固定在安全区之上，带毛玻璃背景。
struct BottomActionBar<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: Tokens.compactSpacing) { content }
            .padding(.horizontal, Tokens.padding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: Tokens.maxContentWidth)
            .frame(maxWidth: .infinity)
            .background(.bar)
    }
}
