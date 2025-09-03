import SwiftUI
import NavigatorUI

struct ScreenBView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		VStack {
			Text("Screen B")

			Button("Back") {
				navigator.back()
			}

			Button("Route to Screen A") {
				navigator.perform(route: AppRoutes.screenA)
			}
		}
	}
}
