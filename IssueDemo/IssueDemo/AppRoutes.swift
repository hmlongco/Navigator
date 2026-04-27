import NavigatorUI

enum AppRoutes: NavigationRoutes {
	case screenC

	struct Handler: NavigationRouteHandling {
		@MainActor
		func route(to route: AppRoutes, with navigator: Navigator) {
			switch route {
			case .screenC:
				navigator.perform(
					.reset,
					.send(ScreenADestinations.screenC)
				)
			}
		}
	}
}
