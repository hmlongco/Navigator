import SwiftUI
import NavigatorUI

struct HomeView: View {
	@Environment(\.navigator)
	private var navigator

	@State
	private var viewModel: HomeViewModel = .init()

	var body: some View {
		VStack {
			Text("Home")

			// This pushin screens directly via navigator which is working fine.
			Button {
				navigator.navigate(to: HomeDestinations.screenA)
			} label: {
				Text("Push A directly")
			}

			// This is using the navigate(to:) view modifier and it's working fine for pushing screens.
			Button {
				viewModel.navigateToScreenA()
			} label: {
				Text("Push A via ViewModel")
			}

			// This presents sheets directly via the navigator which is working fine.
			Button {
				navigator.navigate(to: HomeDestinations.screenB)
			} label: {
				Text("Present B directly")
			}

			// This shows the issue when using the navigate(to:) view modifier for sheet presentation.
			// And after trying this it also stops the first two buttons from working properly.
			Button {
				viewModel.navigateToScreenB()
			} label: {
				Text("Present B via ViewModel (issue)")
			}
		}
		.navigationTitle("Home")
		// The used binding for navigations via the ViewModel.
		.navigate(to: $viewModel.navigationDestination)
		.navigationDestination(HomeDestinations.self)
	}
}

@Observable
final class HomeViewModel {
	// No direct dependency to the navigator in ViewModels, instead a binding is used.
	var navigationDestination: HomeDestinations?

	func navigateToScreenA() {
		navigationDestination = .screenA
	}

	func navigateToScreenB() {
		navigationDestination = .screenB
	}
}

enum HomeDestinations: NavigationDestination {
	// Screen A will always be pushed.
	case screenA
	// Screen B should be presented.
	case screenB

	var body: some View {
		switch self {
		case .screenA:
			ScreenA()
		case .screenB:
			// It seems wrapping the view in a ManagedNavigationStack is participating to the issue.
			// When removing it then presenting directly still works as expected (without showing a navigation bar),
			// but presenting via the ViewModel still reveals a different problem.
			// Now ScreenB still shows a navigation bar and the screen gets pushed instead of presented,
			// only be removing the ManagedNavigationStack here.
			ManagedNavigationStack {
				ScreenB()
			}
		}
	}

	var method: NavigationMethod {
		switch self {
		case .screenA:
			// Using push is working fine.
			.push
		case .screenB:
			// Whether using sheet or cover, both are resulting in the same issue.
			.sheet
		}
	}
}
