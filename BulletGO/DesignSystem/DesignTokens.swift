import SwiftUI

enum DesignTokens {
    enum Color {
        static let canvas = SwiftUI.Color(uiColor: .systemBackground)
        static let grouped = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let quietFill = SwiftUI.Color(uiColor: .tertiarySystemFill)
        static let tint = SwiftUI.Color.accentColor
        static let primaryText = SwiftUI.Color.primary
        static let secondaryText = SwiftUI.Color.secondary
    }

    enum Typography {
        static let title = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.subheadline
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum TapTarget {
        static let minimum: CGFloat = 44
    }
}
