import SwiftUI
import NavigatorUI

struct TabsView: View {
	enum Tabs {
		case tab1
	}

	@State var selectedTab: Tabs = .tab1

	var body: some View {
		TabView(selection: $selectedTab) {
			Tab(value: Tabs.tab1) {
				ManagedNavigationStack {
					ScreenAView()
				}
			} label: {
				Label("TabsView", systemImage: "house")
			}
		}
		.onNavigationReceive(assign: $selectedTab)
	}
}
