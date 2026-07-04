//
//  AppLayout.swift
//  HotTub
//

import SwiftUI
import UIKit

/// Chooses between phone and iPad presentation. iPhone UI stays on compact phone idiom only.
enum AppLayout {
    /// Portrait width of 11″ iPad class devices (Air / Pro 11″, 10.9″ iPad).
    static let iPad11ReferenceWidth: CGFloat = 820

    /// Minimum container width to use iPad layouts (matches 11″ portrait short side).
    static let padLayoutMinimumWidth: CGFloat = iPad11ReferenceWidth

    /// Fallback before layout geometry is measured (full-screen iPad).
    static var defaultUsePadLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        let bounds = UIScreen.main.bounds
        return max(bounds.width, bounds.height) >= padLayoutMinimumWidth
    }

    static func usePadLayout(availableWidth: CGFloat) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        return availableWidth >= padLayoutMinimumWidth
    }

    static func isLandscape(size: CGSize) -> Bool {
        size.width > size.height
    }
}

private struct IsLandscapeKey: EnvironmentKey {
    static let defaultValue: Bool = {
        let bounds = UIScreen.main.bounds
        return AppLayout.isLandscape(size: bounds.size)
    }()
}

extension EnvironmentValues {
    var isLandscape: Bool {
        get { self[IsLandscapeKey.self] }
        set { self[IsLandscapeKey.self] = newValue }
    }
}

private struct UsePadLayoutKey: EnvironmentKey {
    static let defaultValue: Bool = AppLayout.defaultUsePadLayout
}

extension EnvironmentValues {
    var usePadLayout: Bool {
        get { self[UsePadLayoutKey.self] }
        set { self[UsePadLayoutKey.self] = newValue }
    }
}

/// Max widths and gutters tuned for 11″ iPad; scales down on narrower containers.
enum PadContentLayout {
    /// Single-column forms (Setup, etc.).
    static let settingsMaxWidth: CGFloat = 640
    static let readableMaxWidth: CGFloat = 680
    /// Wider canvas for dashboard and charts on iPad.
    static let dashboardMaxWidth: CGFloat = 960
    static let horizontalGutter: CGFloat = 24

    /// Chemistry line charts — taller on iPad for readability.
    static let chemistryChartHeightPhone: CGFloat = 150
    static let chemistryChartHeightPad: CGFloat = 220
    static let usersChartHeightPhone: CGFloat = 220
    static let usersChartHeightPad: CGFloat = 260

    /// History master–detail split column.
    static let historyListMinWidth: CGFloat = 340
    static let historyListIdealWidth: CGFloat = 400

    /// Floating pill tab bar — compact on 13″, nearly full width on 11″.
    static let tabBarOuterHorizontalPadding: CGFloat = 16
    static let tabBarTopPadding: CGFloat = 8
    static let tabBarBottomPadding: CGFloat = 8
    static let tabBarPillInnerPadding: CGFloat = 8
    static let tabBarPillVerticalPadding: CGFloat = 8
    static let tabBarItemSpacing: CGFloat = 4
    static let tabBarItemHorizontalPadding: CGFloat = 8
    static let tabBarItemVerticalPadding: CGFloat = 8
    static let tabBarIconSize: CGFloat = 20
    static let tabBarShadowRadius: CGFloat = 8
    static let tabBarShadowYOffset: CGFloat = 2
    /// 13″ iPad landscape width and wider — keep the compact centred pill.
    static let tabBarCompactPillThreshold: CGFloat = 1_280
    static let tabBarCompactPillMaxWidth: CGFloat = 780
    /// Horizontal scale applied to the pill width (0.85 = 15% narrower).
    static let tabBarPillWidthScale: CGFloat = 0.85

    static func tabBarPillWidth(for availableWidth: CGFloat) -> CGFloat {
        let margins = tabBarOuterHorizontalPadding * 2
        let baseWidth: CGFloat
        if availableWidth >= tabBarCompactPillThreshold {
            baseWidth = min(tabBarCompactPillMaxWidth, availableWidth - margins)
        } else {
            baseWidth = availableWidth - margins
        }
        return baseWidth * tabBarPillWidthScale
    }

    static func tabBarFont(for availableWidth: CGFloat) -> Font {
        let size: CGFloat = availableWidth >= tabBarCompactPillThreshold ? 13 : 14
        return .system(size: size)
    }
}

private struct PadReadableContentModifier: ViewModifier {
    @Environment(\.usePadLayout) private var usePadLayout
    var maxWidth: CGFloat = PadContentLayout.readableMaxWidth

    func body(content: Content) -> some View {
        if usePadLayout {
            content
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, PadContentLayout.horizontalGutter)
        } else {
            content
        }
    }
}

extension View {
    /// Centers content on iPad with side margins; no-op on iPhone.
    func padReadableContent(maxWidth: CGFloat = PadContentLayout.readableMaxWidth) -> some View {
        modifier(PadReadableContentModifier(maxWidth: maxWidth))
    }

    /// Scroll padding that adapts bottom inset for iPad (no tab bar).
    func appAdaptiveScrollPadding(usePadLayout: Bool) -> some View {
        padding(.horizontal, usePadLayout ? PadContentLayout.horizontalGutter : AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, usePadLayout ? AppSpacing.screenBottom : AppSpacing.scrollBottom)
    }
}
