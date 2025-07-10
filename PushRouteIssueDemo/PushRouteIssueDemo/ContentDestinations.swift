import NavigatorUI
import SwiftUI

enum ContentDestinations: NavigationDestination {
	case screenA
	case screenB

	var body: some View {
		switch self {
		case .screenA:
			ManagedNavigationStack {
				ScreenAView()
			}
		case .screenB:
			ManagedNavigationStack {
				ScreenBView()
			}
		}
	}

	var method: NavigationMethod {
		switch self {
		case .screenA, .screenB:
			.sheet
		}
	}
}
