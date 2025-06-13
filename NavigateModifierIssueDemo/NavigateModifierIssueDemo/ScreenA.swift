import SwiftUI
import NavigatorUI

struct ScreenA: View {
	@Environment(\.navigator)
	private var navigator

	var body: some View {
		VStack {
			Text("Screen A")

			Button {
				navigator.back()
			} label: {
				Text("Back")
			}
		}
		.navigationTitle("Screen A")
	}
}
