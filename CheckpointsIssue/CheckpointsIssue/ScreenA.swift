import SwiftUI
import NavigatorUI

struct ScreenA: View {
	@Environment(\.navigator) var navigator: Navigator

	var body: some View {
		VStack {
			Text("Screen A")

			Button {
				navigator.navigate(to: ScreenADestinations.screenB)
			} label: {
				Text("Navigate to Screen B")
			}
		}
		.navigationCheckpoint(Checkpoints.screenA)
	}
}

nonisolated enum ScreenADestinations: NavigationDestination {
	case screenB

	var body: some View {
		switch self {
		case .screenB:
			ScreenB()
		}
	}

	var method: NavigationMethod {
		switch self {
		case .screenB:
			.managedCover
		}
	}
}
