import SwiftUI
import NavigatorUI

struct ScreenCView: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		ZStack {
			Color.green.ignoresSafeArea()
			VStack {
				Text("Screen C")

				Button("Back") {
					navigator.back()
				}
			}
		}
	}
}
