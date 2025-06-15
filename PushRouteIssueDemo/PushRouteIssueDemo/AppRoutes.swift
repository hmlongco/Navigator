import NavigatorUI

enum AppRoutes: NavigationRoutes {
	case screenA

	struct Handler: NavigationRouteHandling {
		@MainActor
		func route(to route: AppRoutes, with navigator: Navigator) {
			switch route {
			case .screenA:
				navigator.perform(
					.reset,
					.send(ContentDestinations.screenA)
				)
			}
		}
	}
}
