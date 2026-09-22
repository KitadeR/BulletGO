import SwiftUI
import UIKit

enum DesignTokens {
    enum Color {
        static let canvas = adaptive(
            light: UIColor(red: 0.973, green: 0.973, blue: 0.980, alpha: 1),
            dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        )
        static let grouped = adaptive(
            light: UIColor(red: 0.941, green: 0.941, blue: 0.949, alpha: 1),
            dark: UIColor(red: 0.22, green: 0.22, blue: 0.23, alpha: 1)
        )
        static let quietFill = grouped
        static let elevated = adaptive(
            light: .white,
            dark: UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1)
        )
        static let ctaFill = adaptive(
            light: UIColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1),
            dark: .white
        )
        static let ctaText = adaptive(
            light: .white,
            dark: .black
        )
        static let ctaDisabledFill = adaptive(
            light: UIColor(red: 0.878, green: 0.878, blue: 0.898, alpha: 1),
            dark: UIColor.white.withAlphaComponent(0.12)
        )
        static let ctaDisabledText = adaptive(
            light: UIColor(red: 0.569, green: 0.569, blue: 0.600, alpha: 1),
            dark: UIColor.white.withAlphaComponent(0.35)
        )
        static let inputStroke = adaptive(
            light: UIColor(red: 0.878, green: 0.878, blue: 0.898, alpha: 1),
            dark: UIColor.white.withAlphaComponent(0.12)
        )
        static let tint = ctaFill
        static let tintSoft = grouped
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let success = SwiftUI.Color(red: 0.18, green: 0.56, blue: 0.38)
        static let caution = SwiftUI.Color(red: 0.78, green: 0.52, blue: 0.12)
        static let danger = SwiftUI.Color(red: 0.72, green: 0.28, blue: 0.24)
        static let remembered = SwiftUI.Color.secondary
        static let now = primaryText
        static let stroke = SwiftUI.Color.primary.opacity(0.08)
        static let contrastStroke = SwiftUI.Color.primary.opacity(0.45)

        private static func adaptive(light: UIColor, dark: UIColor) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        }
    }

    enum Typography {
        static let display = Font.largeTitle.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.subheadline
        static let footnote = Font.footnote
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let section: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let hero: CGFloat = 32
    }

    enum TapTarget {
        static let minimum: CGFloat = 44
    }

    enum Shadow {
        static let cardColor = SwiftUI.Color.black.opacity(0.08)
        static let cardRadius: CGFloat = 18
        static let cardY: CGFloat = 8
    }

    enum Motion {
        static let duration: Double = 0.36
        static let quick: Double = 0.22
        static let spring = Animation.spring(duration: 0.36, bounce: 0.12)

        static func content(_ reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeInOut(duration: quick) : spring
        }
    }
}
