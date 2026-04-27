import SwiftUI
import NavigatorUI

struct ScreenAView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		VStack {
			Text("Screen A")

			Button {
				navigator.navigate(to: ScreenADestinations.screenB)
			} label: {
				Text("Navigate to Screen B")
			}

			Button {
				navigator.navigate(to: ScreenADestinations.screenC)
			} label: {
				Text("Navigate to Screen C")
			}

			Button {
				navigator.perform(route: AppRoutes.screenC)
			} label: {
				Text("Route to Screen C")
			}
		}
		.navigationAutoReceive(ScreenADestinations.self)
	}
}

enum ScreenADestinations: NavigationDestination {
	case screenB
	case screenC

	var body: some View {
		switch self {
		case .screenB:
			ScreenBView()
		case .screenC:
			ScreenCView()
		}
	}

	var method: NavigationMethod {
		switch self {
		case .screenB:
			// Returning here `.managedCover` solves the issue.
			.managedSheet
		case .screenC:
			.managedCover
		}
	}
}
