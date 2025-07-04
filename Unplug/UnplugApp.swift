import SwiftUI

@main
struct UnplugApp: App {
    var body: some Scene {
        WindowGroup {
            // Use a TabView to switch between the two main features
            TabView {
                UnplugView()
                    .tabItem {
                        Label("Unplug", systemImage: "bolt.fill")
                    }

                HobbiesView()
                    .tabItem {
                        Label("New Hobbies", systemImage: "sparkles.magnifyingglass")
                    }
            }
        }
    }
}
