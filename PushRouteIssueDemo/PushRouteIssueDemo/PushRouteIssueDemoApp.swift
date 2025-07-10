import SwiftUI
import NavigatorUI

// To reproduce the issue:
// Tap on "Open Screen B"
// Tap on "Route to Screen A"
// Tap on "Back"
// Expected behavior: Screen A closes
// Current behavior: Nothing happens
@main
struct PushRouteIssueDemoApp: App {
	let rootNavigator: Navigator = {
		let configuration = NavigationConfiguration()
		return Navigator(configuration: configuration)
	}()

    var body: some Scene {
        WindowGroup {
			ManagedNavigationStack {
				ContentView()
			}
			// Commenting out this line solves the issue.
			.environment(\.navigator, rootNavigator)
        }
    }
}
