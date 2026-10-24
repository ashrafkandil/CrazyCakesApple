import Foundation
import CoreText

/// Finds bundled media/font files regardless of whether Xcode keeps the
/// resource folders or flattens them into the app bundle.
enum BundleResource {
    private static let subdirectories: [String?] = [
        nil,
        "Images",
        "Videos",
        "Fonts",
        "Resources",
        "Resources/Images",
        "Resources/Videos",
        "Resources/Fonts",
    ]

    static func url(named name: String, ext: String) -> URL? {
        for directory in subdirectories {
            if let found = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return found
            }
        }
        return nil
    }

    /// Resolves a bundled media file name from MediaRegistry.
    static func url(forMediaFile file: String) -> URL? {
        let ext = (file as NSString).pathExtension
        let name = (file as NSString).deletingPathExtension
        return url(named: name, ext: ext)
    }
}

enum FontLoader {
    /// Exactly the families the React Native app loads from @expo-google-fonts.
    static let fontFiles = [
        "Inter-Regular",
        "Inter-Medium",
        "Inter-SemiBold",
        "Inter-Bold",
        "DancingScript-Regular",
        "DancingScript-Medium",
        "DancingScript-SemiBold",
        "DancingScript-Bold",
        "CrimsonText-Regular",
        "CrimsonText-Italic",
        "CrimsonText-SemiBold",
    ]

    static func registerBundledFonts() {
        for file in fontFiles {
            guard let url = BundleResource.url(named: file, ext: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
