//
//  CounterFlow.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

/// A minimal flow that pushes the same step view three times in a row.
///
/// Doesn't return a value and isn't anchored to a named checkpoint — uses the
/// default indexed anchor via plain `navigator.start(_:)` and pops back when
/// `next()` returns `.complete(self)` after the third step.
nonisolated struct CounterFlow: NavigationFlow {

    var checkpoint: NavigationFlowCheckpoint<Void>?

    var count: Int = 1

    nonisolated enum Destination: NavigationDestination {
        case step(CounterFlow)

        var body: some View {
            switch self {
            case .step(let flow):
                CounterStepView(flow)
            }
        }
    }

    func start() -> FlowResult<Self> {
        .destination(.step(self))
    }

    func next() async throws -> FlowResult<Self> {
        if count < 3 {
            return .destination(.step(copy { $0.count += 1 }))
        }
        return .complete(self)
    }
}

struct CounterStepView: View {
    @Environment(\.navigator) private var navigator
    let flow: CounterFlow

    init(_ flow: CounterFlow) {
        self.flow = flow
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("View \(flow.count)")
                .font(.largeTitle)
            Button(flow.count < 3 ? "Next" : "Done") {
                Task { try? await navigator.next(flow) }
            }
            .buttonStyle(.bordered)
            Button("Cancel") {
                navigator.cancel(flow)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .tint(.primary)
        .navigationTitle("Counter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
