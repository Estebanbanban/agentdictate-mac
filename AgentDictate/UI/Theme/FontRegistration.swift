import AppKit
import CoreText

enum CortanaFonts {
    static let orbitronBold = "Orbitron-Bold"
    static let orbitronRegular = "Orbitron-Regular"
    static let jetbrainsMono = "JetBrainsMono-Regular"

    /// Registers bundled fonts so SwiftUI / AppKit can address them by PostScript name.
    /// Idempotent — calling more than once is harmless.
    static func registerAll(bundle: Bundle = .main) {
        register(name: "Orbitron-Bold", ext: "ttf", in: bundle)
        register(name: "Orbitron-Regular", ext: "ttf", in: bundle)
        register(name: "JetBrainsMono-Regular", ext: "ttf", in: bundle)
    }

    private static func register(name: String, ext: String, in bundle: Bundle) {
        let candidates: [URL?] = [
            bundle.url(forResource: name, withExtension: ext),
            bundle.url(forResource: name, withExtension: ext, subdirectory: "Fonts"),
            bundle.resourceURL?.appendingPathComponent("Fonts/\(name).\(ext)")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            NSLog("AgentDictate: font asset \(name).\(ext) not found in bundle")
            return
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok {
            let code = (error?.takeRetainedValue() as Error?).map { ($0 as NSError).code } ?? -1
            if code != 105 { // 105 = already registered
                NSLog("AgentDictate: failed to register \(name) (code=\(code))")
            }
        }
    }
}
