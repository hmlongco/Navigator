import SwiftUI
import NavigatorUI

struct ScreenBView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		ZStack {
			Color.yellow.ignoresSafeArea()
			VStack {
				Text("Screen B")

				Button("Back") {
					navigator.back()
				}

				Button("Route to Screen C") {
					navigator.perform(route: AppRoutes.screenC)
				}
			}
		}
		// Removing this modifier or passing nil will resolve the navigation issue.
		.preferredColorScheme(.light)
	}
}
