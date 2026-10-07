 import SwiftUI

@main
struct OspanSammanstallningApp: App {
    var body: some Scene {
        Window("O-Span-sammanställning", id: "huvud") {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 800)
    }
}
