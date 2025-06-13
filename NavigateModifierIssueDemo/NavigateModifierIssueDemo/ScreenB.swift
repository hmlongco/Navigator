import SwiftUI
import NavigatorUI

struct ScreenB: View {
	@Environment(\.navigator)
	private var navigator

	var body: some View {
		VStack {
			Text("Screen B")

			Button {
				navigator.back()
			} label: {
				Text("Back")
			}
		}
		.navigationTitle("Screen B")
	}
}
