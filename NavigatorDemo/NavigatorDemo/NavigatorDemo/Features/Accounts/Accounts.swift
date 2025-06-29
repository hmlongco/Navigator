//
//  Accounts.swift
//  NavigatorDemo
//
//  Created by Michael Long on 1/8/25.
//

import NavigatorUI
import SwiftUI

enum AccountDestinations {
    case details(Account)
    case disclaimers(Account)
}

extension AccountDestinations: NavigationDestination {
    public var body: some View {
        switch self {
        case .details(let account):
            AccountDetailsView(account: account)
        case .disclaimers(let account):
            AccountDisclaimersView(account: account)
        }
    }
}

struct PresentAccountDestinationsView: View {
    let account: Account
    @State var presentView: AccountDestinations?
    var body: some View {
        List {
            Button("Present Account Details") {
                presentView = .details(account)
            }
            Button("Present Account Disclaimers") {
                presentView = .disclaimers(account)
            }
            .sheet(item: $presentView) { destination in
                destination()
            }
        }
    }
}

struct AccountsView: View {
    let account: Account
    var body: some View {
        List {
            Section("Account Actions") {
                NavigationLink("Details", value: AccountDestinations.disclaimers(account))
                NavigationLink("Disclaimers", value: AccountDestinations.disclaimers(account))
            }
        }
        .navigationDestination(AccountDestinations.self)
    }
}

struct AccountDetailsView: View {
    let account: Account
    var body: some View {
        Text("Account Details")
    }
}

struct AccountDisclaimersView: View {
    let account: Account
    var body: some View {
        Text("Account Disclaimers")
    }
}

struct Account: Hashable {}
