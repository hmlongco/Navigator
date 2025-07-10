import SwiftUI
import NavigatorUI

struct ScreenAView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		VStack {
			Text("Screen A")

			Button("Back") {
				navigator.back()
			}
		}
	}
}
