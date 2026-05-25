import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct OrbisonicApp: App {
    init() {
        RuntimeAppIcon.install()
    }

    var body: some Scene {
        WindowGroup("Orbisonic") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}

private enum RuntimeAppIcon {
    static func install() {
        #if canImport(AppKit)
        guard let iconURL = Bundle.main.url(forResource: "Orbisonic", withExtension: "icns"),
              let image = NSImage(contentsOf: iconURL) else {
            return
        }

        DispatchQueue.main.async {
            NSApplication.shared.applicationIconImage = image
        }
        #endif
    }
}
