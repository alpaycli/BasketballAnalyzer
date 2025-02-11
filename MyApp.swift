import TipKit
import SwiftUI

@main
struct MyApp: App {
    init() {
//        try? Tips.resetDatastore()
        try? Tips.configure(
            [
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ]
        )
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
