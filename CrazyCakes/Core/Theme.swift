import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

/// Design tokens mirrored one-for-one from the React Native app's src/theme.ts.
enum Palette {
    static let background = Color(hex: 0xFDFDFD)
    static let foreground = Color(hex: 0x2F2322)
    static let card = Color(hex: 0xFFFFFF)
    static let primary = Color(hex: 0xE58F92)
    static let primaryForeground = Color(hex: 0xFEFBFB)
    static let secondary = Color(hex: 0xF5CCCD)
    static let muted = Color(hex: 0xFAF1F1)
    static let mutedForeground = Color(hex: 0x766867)
    static let border = Color(hex: 0xEADAD9)
    static let blush = Color(hex: 0xFFF4F4)
    static let gold = Color(hex: 0xD29E25)
    static let overlay = Color(hex: 0x0D0605, alpha: 0.58)
    static let overlaySoft = Color(hex: 0x0D0605, alpha: 0.35)
    static let overlayStrong = Color(hex: 0x0D0605, alpha: 0.65)
    static let footer = Color(hex: 0x231716)
    static let footerForeground = Color(hex: 0xF8EFEF)

    /// The rgba(248, 239, 239, alpha) blends used by the footer and splash.
    static func footerAlpha(_ alpha: Double) -> Color {
        Color(hex: 0xF8EFEF, alpha: alpha)
    }
}

/// Font accessors that match the React Native fonts map.
enum AppFont {
    static func script(_ size: CGFloat) -> Font {
        .custom("DancingScript-Regular", size: size)
    }

    static func scriptSemiBold(_ size: CGFloat) -> Font {
        .custom("DancingScript-SemiBold", size: size)
    }

    static func serif(_ size: CGFloat) -> Font {
        .custom("CrimsonText-Regular", size: size)
    }

    static func serifItalic(_ size: CGFloat) -> Font {
        .custom("CrimsonText-Italic", size: size)
    }

    static func serifSemiBold(_ size: CGFloat) -> Font {
        .custom("CrimsonText-SemiBold", size: size)
    }

    static func inter(_ size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }

    static func interMedium(_ size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }

    static func interSemiBold(_ size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }

    static func interBold(_ size: CGFloat) -> Font {
        .custom("Inter-Bold", size: size)
    }
}

enum Metrics {
    /// eyebrowLetterSpacing in src/theme.ts.
    static let eyebrowLetterSpacing: CGFloat = 2.9

    static let pageHorizontalPadding: CGFloat = 20
}
