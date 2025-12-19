import SwiftUI
import NavigatorUI

struct ScreenB: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		Text("Screen B")

		Button {
			// Starting with v1.4.0 the following stopped working, with v1.3.1 it's working.
			navigator.returnToCheckpoint(Checkpoints.screenA)
		} label: {
			Text("Close")
		}
	}
}
