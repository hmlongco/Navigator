import SwiftUI
import NavigatorUI

struct ContentView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
        VStack {
            Text("Content")

			Button {
				navigator.navigate(to: ContentDestinations.screenA)
			} label: {
				Text("Open Screen A")
			}

			Button {
				navigator.navigate(to: ContentDestinations.screenB)
			} label: {
				Text("Open Screen B")
			}
        }
		.navigationDestination(ContentDestinations.self)
		.onNavigationRoute(AppRoutes.Handler())
		.onNavigationReceive { (destination: ContentDestinations, navigator) in
			navigator.navigate(to: destination)
			return .auto
		}
    }
}
