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

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1
        )
    }
}

/// Dynamic palette that loads from the theme repository
@MainActor
final class PaletteManager: ObservableObject {
    static let shared = PaletteManager()

    @Published var theme: Theme? = nil
    @Published var themes: [Theme] = []

    private let repository = ThemeRepository.shared

    private init() {
        loadThemes()
    }

    func loadThemes() {
        Task {
            do {
                try await repository.loadThemes()
                await MainActor.run {
                    self.themes = repository.allThemes
                    self.theme = repository.defaultTheme
                }
            } catch {
                print("Failed to load themes: \(error)")
                // Fallback to default Pink theme
            }
        }
    }

    func setDefaultTheme(_ theme: Theme) async {
        do {
            try await repository.setDefaultTheme(id: theme.id)
            await MainActor.run {
                self.theme = theme
            }
        } catch {
            print("Failed to set theme: \(error)")
        }
    }

    var allThemes: [Theme] { themes }

    // Current theme or fallback to Pink
    var currentTheme: Theme {
        theme ?? defaultTheme
    }

    private var defaultTheme: Theme {
        Theme(
            id: 1,
            name: "Pink",
            primaryColor: "#e8b4b8",
            primaryForeground: "#ffffff",
            secondaryColor: "#fce4ec",
            secondaryForeground: "#4a2c2e",
            background: "#fdf8f8",
            surface: "#ffffff",
            muted: "#f5e6e6",
            mutedForeground: "#8b6b6b",
            border: "#e8b4b8",
            gold: "#d4a574",
            overlay: "#00000040",
            blush: "#ffe4e6",
            isDefault: true,
            sort: 1
        )
    }
}

// Dynamic palette accessors - these will use the current theme
@MainActor
final class Palette {
    static let shared = PaletteManager.shared

    // Dynamic color accessors - use the current theme
    static var background: Color {
        shared.currentTheme.backgroundColor
    }

    static var foreground: Color {
        shared.currentTheme.foregroundColor
    }

    static var card: Color {
        shared.currentTheme.surfaceColor
    }

    static var primary: Color {
        shared.currentTheme.primaryColor
    }

    static var primaryForeground: Color {
        shared.currentTheme.primaryForegroundColor
    }

    static var secondary: Color {
        shared.currentTheme.secondaryColor
    }

    static var secondaryForeground: Color {
        shared.currentTheme.secondaryForegroundColor
    }

    static var muted: Color {
        shared.currentTheme.mutedColor
    }

    static var mutedForeground: Color {
        shared.currentTheme.mutedForegroundColor
    }

    static var border: Color {
        shared.currentTheme.borderColor
    }

    static var blush: Color {
        shared.currentTheme.blushColor
    }

    static var gold: Color {
        shared.currentTheme.goldColor
    }

    static var overlay: Color {
        shared.currentTheme.overlayColor
    }

    static var overlaySoft: Color {
        shared.currentTheme.overlaySoftColor
    }

    static var overlayStrong: Color {
        shared.currentTheme.overlayStrongColor
    }

    static var footer: Color {
        shared.currentTheme.footerColor
    }

    static var footerForeground: Color {
        shared.currentTheme.footerForegroundColor
    }

    /// The rgba(248, 239, 239, alpha) blends used by the footer and splash.
    static func footerAlpha(_ alpha: Double) -> Color {
        Palette.shared.currentTheme.footerColor.opacity(alpha)
    }
}

/// Theme model for dynamic theme loading
struct Theme: Identifiable, Hashable {
    let id: Int
    let name: String
    let primaryColor: String
    let primaryForeground: String
    let secondaryColor: String
    let secondaryForeground: String
    let background: String
    let surface: String
    let muted: String
    let mutedForeground: String
    let border: String
    let gold: String
    let overlay: String
    let blush: String
    let isDefault: Bool
    let sort: Int

    // Computed Color properties
    var primaryColor: Color { Color(hexString: primaryColor) }
    var primaryForegroundColor: Color { Color(hexString: primaryForeground) }
    var secondaryColor: Color { Color(hexString: secondaryColor) }
    var secondaryForegroundColor: Color { Color(hexString: secondaryForeground) }
    var backgroundColor: Color { Color(hexString: background) }
    var surfaceColor: Color { Color(hexString: surface) }
    var mutedColor: Color { Color(hexString: muted) }
    var mutedForegroundColor: Color { Color(hexString: mutedForeground) }
    var borderColor: Color { Color(hexString: border) }
    var goldColor: Color { Color(hexString: gold) }
    var overlayColor: Color { Color(hexString: overlay) }
    var blushColor: Color { Color(hexString: blush) }
    var footerColor: Color { Color(hexString: background).opacity(0.9) }
    var footerForegroundColor: Color { Color(hexString: foreground) }

    var overlaySoftColor: Color { overlayColor.opacity(0.35) }
    var overlayStrongColor: Color { overlayColor.opacity(0.65) }
    var foregroundColor: Color { Color(hexString: primaryForeground) }

    var overlayAlpha: Double {
        // Extract alpha from overlay string like "#00000040" -> 0.25
        let hex = overlay.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count >= 8 {
            let alphaHex = String(hex.suffix(2))
            if let alphaValue = UInt64(alphaHex, radix: 16) {
                return Double(alphaValue) / 255.0
            }
        }
        return 0.58
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
