import SwiftUI
import NavigatorUI

@main
struct CheckpointsIssueApp: App {
	let rootNavigator: Navigator = {
		let configuration = NavigationConfiguration(
			logger: { event in
				print(event)
			},
			verbosity: .info
		)
		return Navigator(configuration: configuration)
	}()

    var body: some Scene {
        WindowGroup {
			ManagedNavigationStack {
				ScreenA()
			}
			.environment(\.navigator, rootNavigator)
        }
    }
}
