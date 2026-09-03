import SwiftUI
import UIKit

enum DesignTokens {
    enum Color {
        static let canvas = SwiftUI.Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)
            } else {
                UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1)
            }
        })
        static let grouped = SwiftUI.Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.16, green: 0.14, blue: 0.13, alpha: 1)
            } else {
                UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
            }
        })
        static let quietFill = SwiftUI.Color(uiColor: .tertiarySystemFill)
        static let elevated = SwiftUI.Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.20, green: 0.18, blue: 0.16, alpha: 1)
            } else {
                UIColor.white
            }
        })
        static let tint = SwiftUI.Color(red: 0.86, green: 0.34, blue: 0.22)
        static let tintSoft = SwiftUI.Color(red: 0.86, green: 0.34, blue: 0.22).opacity(0.14)
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
        static let heroSkyTop = SwiftUI.Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.18, green: 0.22, blue: 0.32, alpha: 1)
            } else {
                UIColor(red: 0.62, green: 0.78, blue: 0.90, alpha: 1)
            }
        })
        static let heroSkyBottom = SwiftUI.Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.32, green: 0.24, blue: 0.20, alpha: 1)
            } else {
                UIColor(red: 0.98, green: 0.84, blue: 0.68, alpha: 1)
            }
        })
        static let success = SwiftUI.Color(red: 0.18, green: 0.56, blue: 0.38)
        static let caution = SwiftUI.Color(red: 0.78, green: 0.52, blue: 0.12)
        static let danger = SwiftUI.Color(red: 0.72, green: 0.28, blue: 0.24)
        static let remembered = SwiftUI.Color(red: 0.38, green: 0.42, blue: 0.56)
        static let now = tint
        static let stroke = SwiftUI.Color.primary.opacity(0.08)
        static let contrastStroke = SwiftUI.Color.primary.opacity(0.45)
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
