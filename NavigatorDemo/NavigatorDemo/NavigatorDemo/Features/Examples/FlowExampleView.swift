//
//  FlowExampleView.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

struct FlowExampleView: View {
    var body: some View {
        ManagedNavigationStack { navigator in
            List {
                Section("Navigation Flows") {
                    Button("Start Onboarding Flow") {
                        navigator.start(OnboardingFlow { firstName, lastName, email in
                            try await Task.sleep(for: .seconds(1))
                            print("Onboarded \(firstName) \(lastName) <\(email)>")
                        })
                    }
                }
                Section {
                    Button("Dismiss Example") {
                        navigator.dismiss()
                    }
                }
            }
            .navigationTitle("Flow Examples")
        }
    }
}

nonisolated struct OnboardingFlow: NavigationFlow {
    var checkpoint: NavigationFlowCheckpoint?

    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""

    private let handler: @Sendable (String, String, String) async throws -> Void

    init(firstName: String = "", handler: @escaping @Sendable (String, String, String) async throws -> Void) {
        self.firstName = firstName
        self.handler = handler
    }

    func start() -> FlowResult<Destinations> {
        .destination(.welcome(self))
    }

    mutating func next() -> FlowResult<Destinations> {
        if firstName.isEmpty || lastName.isEmpty {
            return .destination(.name(self))
        }
        if email.isEmpty {
            return .destination(.email(self))
        }
        return .destination(.completed(self))
    }

    func submit() async throws {
        try await handler(firstName, lastName, email)
    }

    static func == (lhs: OnboardingFlow, rhs: OnboardingFlow) -> Bool {
        lhs.checkpoint == rhs.checkpoint
            && lhs.firstName == rhs.firstName
            && lhs.lastName == rhs.lastName
            && lhs.email == rhs.email
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(checkpoint)
        hasher.combine(firstName)
        hasher.combine(lastName)
        hasher.combine(email)
    }
}

extension OnboardingFlow {
    nonisolated enum Destinations: NavigationDestination {
        case welcome(OnboardingFlow)
        case name(OnboardingFlow)
        case email(OnboardingFlow)
        case completed(OnboardingFlow)

        var body: some View {
            switch self {
            case let .welcome(flow):
                WelcomeView(flow)
            case let .name(flow):
                NameView(flow)
            case let .email(flow):
                EmailView(flow)
            case let .completed(flow):
                CompletedView(flow)
            }
        }

        var method: NavigationMethod {
            switch self {
            case .welcome:
                .managedSheet
            default:
                .push
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow
    init(_ flow: OnboardingFlow) {
        self.flow = flow
    }
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome!")
                .font(.largeTitle)
            Text("Let's get you set up. We're going to ask you a few questions before we begin.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Button("Get Started") {
                navigator.next(flow)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .tint(.primary)
        .navigationTitle("Onboarding")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NameView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow
    init(_ flow: OnboardingFlow) {
        self.flow = flow
    }
    var body: some View {
        Form {
            Section("Please enter your first and last name...") {
                TextField("First name", text: $flow.firstName)
                TextField("Last name", text: $flow.lastName)
            }
            Button("Next") {
                navigator.next(flow)
            }
            .disabled(flow.firstName.isEmpty || flow.lastName.isEmpty)
        }
        .tint(.primary)
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmailView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow
    @State var submitting: Bool = false
    @State var errorMessage: String?
    init(_ flow: OnboardingFlow) {
        self.flow = flow
    }
    var body: some View {
        Form {
            Section("Okay \(flow.firstName), please enter your email address.") {
                TextField("", text: $flow.email, prompt: Text("email@exampple.com").foregroundStyle(.secondary))
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Button(submitting ? "Submitting..." : "Submit") {
                Task { await submit() }
            }
            .disabled(submitting || !isValidEmail(flow.email))
        }
        .tint(.primary)
        .navigationTitle("Email Address")
    }

    func submit() async {
        submitting = true
        defer { submitting = false }
        errorMessage = nil
        do {
            try await flow.submit()
            navigator.next(flow)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isValidEmail(_ candidate: String) -> Bool {
        candidate.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }
}

struct CompletedView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow
    init(_ flow: OnboardingFlow) {
        self.flow = flow
    }
    var body: some View {
        VStack(spacing: 16) {
            Text("Completed!")
                .font(.largeTitle)
            Text("That's all there is to it!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Button("Done") {
                navigator.complete(flow)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .tint(.primary)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}

#if DEBUG
#Preview {
    EmailView(OnboardingFlow(firstName: "Michael") { _, _, _ in })
        .preferredColorScheme(.dark)
}
#endif
