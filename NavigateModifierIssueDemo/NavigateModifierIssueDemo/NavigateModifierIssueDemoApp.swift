import SwiftUI
import NavigatorUI

@main
struct NavigateModifierIssueDemoApp: App {
    var body: some Scene {
        WindowGroup {
			ManagedNavigationStack {
				HomeView()
			}
        }
    }
}
