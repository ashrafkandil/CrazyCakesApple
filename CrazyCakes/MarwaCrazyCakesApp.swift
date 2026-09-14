import SwiftUI
import CoreText

@main
struct MarwaCrazyCakesApp: App {
    init() {
        FontLoader.registerBundledFonts()
        AppDatabase.shared.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum BundleResource {
    static func url(named name: String, ext: String) -> URL? {
        let subdirectories: [String?] = [nil, "Images", "Fonts", "Resources", "Resources/Images", "Resources/Fonts"]
        for directory in subdirectories {
            if let found = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return found
            }
        }
        return nil
    }

    static func drawableName(forSrc src: String) -> String {
        let base = (src as NSString).lastPathComponent
        let name = (base as NSString).deletingPathExtension
        return name.replacingOccurrences(of: "-", with: "")
    }

    static func fileExtension(forSrc src: String) -> String {
        (src as NSString).pathExtension
    }
}

enum FontLoader {
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
