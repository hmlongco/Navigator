//
//  NavigationConfiguration.swift
//  Navigator
//
//  Created by Michael Long on 12/1/24.
//

import SwiftUI

public struct NavigationConfiguration {

    /// Provides a basic dependency injection mechanism for view construction
    let container: NavigationContainer?

    /// Provide a restorationKey to enable state restoration in named ManagedNavigationControllers.
    ///
    /// Increment or change the key when adding/removing checkpoints or changing destination types.
    ///
    /// If no restorationKey is provided then navigation state restoration is disabled.
    let restorationKey: String?


    /// Allows the developer to log navigation messages to the console or to their own logging system.
    ///
    /// If logger is nil then--obviously--nothing is logged.
    let logger: ((_ message: String) -> Void)?

    public init(
        container: NavigationContainer? = nil,
        restorationKey: String? = nil,
        logger: ((String) -> Void)? = { print($0) }
    ) {
        self.container = container
        self.restorationKey = restorationKey
        self.logger = logger
    }

}
