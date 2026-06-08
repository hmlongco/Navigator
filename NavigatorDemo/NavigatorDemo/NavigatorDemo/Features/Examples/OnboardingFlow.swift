//
//  OnboardingFlow.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

nonisolated struct OnboardingFlow: NavigationFlow {

    var checkpoint: NavigationFlowCheckpoint<String>?

    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var onboarded: Bool = false

    init(firstName: String = "") {
        self.firstName = firstName
    }

    func start() -> FlowResult<Self> {
        .destination(.welcome(self))
    }

    func next() async throws -> FlowResult<Self> {
        if firstName.isEmpty || lastName.isEmpty {
            return .destination(.name(self))
        }
        if !isValidEmail {
            return .destination(.email(self))
        }
        if !onboarded {
            let copy = copy { $0.onboarded = true }
            return .destination(.onboarded(copy))
        }
        return .completeWithValue(firstName, self)
    }

    var isValidEmail: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

}

extension OnboardingFlow {
    nonisolated enum Destination: NavigationDestination {
        case welcome(OnboardingFlow)
        case name(OnboardingFlow)
        case email(OnboardingFlow)
        case onboarded(OnboardingFlow)

        var body: some View {
            switch self {
            case let .welcome(flow):
                WelcomeView(flow)
            case let .name(flow):
                NameView(flow)
            case let .email(flow):
                EmailView(flow)
            case let .onboarded(flow):
                OnboardedView(flow)
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
                Task { try? await navigator.next(flow) }
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
                Task { try? await navigator.next(flow) }
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
    init(_ flow: OnboardingFlow) {
        self.flow = flow
    }
    var body: some View {
        Form {
            Section("\(flow.firstName), please enter a valid email address.") {
                TextField("", text: $flow.email, prompt: Text("email@exampple.com").foregroundStyle(.secondary))
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
            Button("Submit") {
                Task { try? await navigator.next(flow) }
            }
            .disabled(!flow.isValidEmail)
        }
        .tint(.primary)
        .navigationTitle("Email Address")
    }

}

struct OnboardedView: View {
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
                Task { try? await navigator.next(flow) }
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
    EmailView(OnboardingFlow(firstName: "Michael"))
        .preferredColorScheme(.dark)
}
#endif
