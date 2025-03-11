import TipKit
import SwiftUI

@main
struct MyApp: App {
    init() {
//        UserDefaults.standard.removeObject(forKey: "isFirstLaunch")
//        try? Tips.resetDatastore()
        try? Tips.configure(
            [
                .datastoreLocation(.applicationDefault)
            ]
        )
    }
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    var body: some Scene {
        WindowGroup {
            HomeView()
                .fullScreenCover(isPresented: $isFirstLaunch) {
                    WelcomeView(isShow: $isFirstLaunch)
                }
        }
    }
}
