//
//  ContentView.swift
//  Nav5
//
//  Created by Michael Long on 11/10/24.
//

import NavigatorUI
import SwiftUI

class HomeRootViewModel: ObservableObject {
    @Published var id = UUID()
    internal let resolver: HomeDependencies
    internal let logger: any Logging
    init(resolver: HomeDependencies) {
        self.resolver = resolver
        self.logger = resolver.logger
        logger.log("HomeRootViewModel initialized \(id)")
    }
}

struct HomeRootView: View {
    @StateObject var viewModel: HomeRootViewModel
    var body: some View {
        ManagedNavigationStack(scene: RootTabs.home.id) {
            HomeContentView(viewModel: HomeContentViewModel(resolver: viewModel.resolver, title: "Home Navigation"))
                .navigationCheckpoint(KnownCheckpoints.home)
                .onNavigationReceive { (destination: Home, navigator) in
                    navigator.navigate(to: destination)
                    return .auto
                }
                .navigationModifier(inherits: true) { destination in
                    destination()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
        }
    }
}

class HomeContentViewModel: ObservableObject {
    let title: String
    init(resolver: HomeDependencies, title: String) {
        self.title = title
    }
}

struct HomeContentView: View {
    @StateObject var viewModel: HomeContentViewModel
    @Environment(\.navigator) var navigator
    @Environment(\.navigator.isEmpty) var isEmpty
    @State var destination: Home?
    var body: some View {
        List {
            Section("Navigation Actions") {
                NavigationLink(to: Home.page2) {
                    Text("Link to Page 2!")
                }
                NavigationLink(to: Home.pageN(44)) {
                    Text("Link to Page 44!")
                }
                NavigationLink(to: Home.mapped) {
                    Text("Link to Mapped View! (99)")
                }
                Button("Navigate to Page 55 (Imperative)") {
                    navigator.navigate(to: Home.pageN(55))
                }
                Button("Navigate to Page 56 (Declarative)") {
                    destination = .pageN(56)
                }
                Button("Navigate to Page 57 (Declarative)") {
                    destination = .pageN(57)
                }
            }
            Section("Externally Provided Views") {
                NavigationLink("Link to External View 1!", to: Home.external)
                NavigationLink("Link to External View 2!", to: Home.external2)
                NavigationLink(to: MissingDestinations.missing) {
                    Text("Link to Missing View Provider!")
                }
            }
            Section("Send Actions") {
                Button("Send Home Page 2, 3") {
                    navigator.send(
                        Home.page2,
                        Home.page3
                    )
                }
            }
            ContentRoutingSection()
            SendResumeAuthenticatedView()
            ContentSheetSection()
            ContentCheckpointSection()
            if UIDevice.current.userInterfaceIdiom == .pad {
                Section("Layout") {
                    Button("Toggle Root View Type") {
                        navigator.send(ToogleAppRootType())
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationCheckpoint(KnownCheckpoints.duplicate)
        .navigate(to: $destination)
        .task {
            print("HomeContentView")
        }
        .onChange(of: isEmpty) { _, v in
            print("Empty:", v)
        }
        .onChange(of: navigator) {
            print("Navigator changed") // never prints
        }
    }
}

extension HomeDependencies {
    var homePage2ViewModel: HomePage2ViewModel {
        .init(dependencies: self)
    }
}

class HomePage2ViewModel: ObservableObject {
    let title: String
    init(dependencies: HomeDependencies) {
        title = "Page 2 " + dependencies.loader.load()
        print("HomePage2ViewModel initialized \(ObjectIdentifier(self))")
    }
    deinit {
        print("HomePage2ViewModel deinit \(ObjectIdentifier(self))")
    }
}

struct HomePage2View: View {
    @StateObject var viewModel: HomePage2ViewModel
    @Environment(\.navigator) var navigator: Navigator
    var body: some View {
        List {
            Section("Navigation Actions") {
                NavigationLink(to: Home.page3) {
                    Text("Link to Home Page 3!")
                }
                NavigationLink(to: Home.pageN(55)) {
                    Text("Link to Home Page 55!")
                }
            }
            Section("Find") {
                Button("Clear Home Via Find") {
                    navigator.named("home")?.popAll()
                }
                Button("Clear Settings With Action") {
                    // Roundabout way of doing this, primarily for testing
                    navigator.perform(.with(navigator: RootTabs.settings.id) {
                        $0.popAll()
                    })
                }
            }
            ContentSheetSection()
            ContentCheckpointSection()
            ContentPopSection()
        }
        .navigationCheckpoint(KnownCheckpoints.page2)
        // shows a checkpoint with a void action handler triggered on return
        .navigationCheckpoint(KnownCheckpoints.duplicate) {
            print("DUPLICATE ACTION")
        }
        .navigationTitle(viewModel.title)
    }
}

struct HomePage3View: View {
    let initialValue: Int
    @Environment(\.navigator) var navigator: Navigator
    var body: some View {
        List {
            Section("Navigation Actions") {
                NavigationLink(to: Home.pageN(initialValue)) {
                    Text("Link to Home Page 66!")
                }
                Button("Button Push to Home Page 77") {
                    navigator.push(Home.pageN(77))
                }
            }
            ContentSheetSection()
            ContentCheckpointSection()
            ContentPopSection()
        }
        .navigationTitle("Page 3")
    }
}

class HomePageNViewModel: ObservableObject {
    let number: Int
    let resolver: HomeDependencies
    init(resolver: HomeDependencies, number: Int) {
        self.resolver = resolver
        self.number = number
    }
}

struct HomePageNView: View {
    @StateObject private var viewModel: HomePageNViewModel
    @Environment(\.navigator) var navigator: Navigator
    init(resolver: HomeDependencies, number: Int) {
        self._viewModel = .init(wrappedValue: .init(resolver: resolver, number: number))
    }
    var body: some View {
        List {
            Section("Send Actions") {
                Button("Send Home Page 2, 88, 99") {
                    navigator.send(
                        NavigationAction.popAll(in: RootTabs.home.id),
                        Home.page2,
                        Home.pageN(88),
                        Home.pageN(99)
                    )
                }
                Button("Route To Settings Page 2") {
                    try? viewModel.resolver.homeExternalRouter.route(to: .settingsPage2)
                }
            }
            ContentSheetSection()
            ContentCheckpointSection()
            ContentPopSection()
        }
        .navigationTitle("Page \(viewModel.number)")
    }
}

struct NestedHomeContentView: View {
    var title: String
    var body: some View {
        // Demonstrates using destinations to build root views that may have dependencies.
        HomeDestinations.home(title)
    }
}

#if DEBUG
#Preview {
    // Demonstrates using destinations to build root views that may have dependencies.
    // Also mocking network call results for these types.
    RootTabs.home
        .setAuthenticationRoot()
        .environment(\.homeDependencies, MockHomeResolver()
            .mock { "(M5)" }
            .mock { 222 }
        )
}
#endif
