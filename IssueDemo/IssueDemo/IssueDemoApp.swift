import SwiftUI
import NavigatorUI

@main
struct IssueDemoApp: App {
	// Setting this to false will remove the TabsView from the view hierarchy which will solve the navigation issue.
	// True: App -> TabsView -> SceenA -> ScreenB or C
	// False: App -> ScreenA -> ScreenB or C
	let useTabsView = true

	let rootNavigator: Navigator = {
		let configuration = NavigationConfiguration(logger: { print($0) })
		return Navigator(configuration: configuration)
	}()

	var body: some Scene {
		WindowGroup {
			if useTabsView {
				TabsView()
					.onNavigationRoute(AppRoutes.Handler())
					.environment(\.navigator, rootNavigator)
			} else {
				ManagedNavigationStack {
					ScreenAView()
						.onNavigationRoute(AppRoutes.Handler())
				}
				.environment(\.navigator, rootNavigator)
			}
		}
	}
}
