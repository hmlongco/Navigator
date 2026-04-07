//
//  NavigationEventLogging.swift
//  Navigator
//
//  Created by Michael Long on 3/17/25.
//

import Foundation

extension Navigator {
    /// Logs a navigation event using the configured logger.
    ///
    /// This method respects the current ``NavigationConfiguration/verbosity``
    /// setting. If logging is disabled or no logger is installed, the call
    /// is a no-op.
    ///
    /// - Parameter event: The event to record.
    public func log(_ event: NavigationEvent.Event) {
        guard let configuration, let logger = configuration.logger else {
            return
        }
        let verbosity: NavigationEvent.Verbosity
        switch event {
        case .warning:
            verbosity = .warning
        case .error:
            verbosity = .error
        default:
            verbosity = .info
        }
        guard verbosity.rawValue >= configuration.verbosity.rawValue else {
            return
        }
        logger(.init(verbosity: .info, navigator: id, navigatorName: name, event: event, timestamp: Date()))
    }
}

/// A single navigation log entry produced by a ``Navigator``.
///
/// The default logger prints the description of these events during
/// development, but you can provide your own logger via
/// ``NavigationConfiguration/logger``.
nonisolated public struct NavigationEvent: CustomStringConvertible {

    let verbosity: Verbosity
    let navigator: UUID
    let navigatorName: String?
    let event: Event
    let timestamp: Date

    /// A human-readable description suitable for logging.
    public var description: String {
        if let navigatorName {
            "Navigator \(navigator) (\(navigatorName)) \(event)"
        } else {
            "Navigator \(navigator) \(event)"
        }
    }

}

extension NavigationEvent {

    /// Controls which events are emitted by the logger.
    public enum Verbosity: Int {
        case info
        case warning
        case error
        case none
    }

}

extension NavigationEvent {

    /// High-level navigation events emitted by a ``Navigator``.
    nonisolated public enum Event: CustomStringConvertible {

        case lifecycle(LifecycleEvent)
        case navigation(NavigationEvent)
        case providing(ProvidingEvent)
        case checkpoint(CheckpointEvent)
        case send(SendEvent)

        case message(String)
        case warning(String)
        case error(String)

        nonisolated public var description: String {
            switch self {
            case .lifecycle(let event):
                return "\(event)"
            case .navigation(let event):
                return "\(event)"
            case .providing(let event):
                return "providing \(event)"
            case .checkpoint(let event):
                return "checkpoint \(event)"
            case .send(let event):
                return "\(event)"
            case .message(let message):
                return message
            case .warning(let message):
                return message
            case .error(let message):
                return message
            }
        }

        /// Lifecycle events for a given navigator instance.
        nonisolated public enum LifecycleEvent: CustomStringConvertible {
            case configured
            case intialized
            case adding(UUID, name: String?)
            case removing(UUID, name: String?)
            case `deinit`

            nonisolated public var description: String {
                switch self {
                case .configured: "configured"
                case .intialized: "intialized"
                case .adding(let id, let name):
                    if let name {
                        "adding \(id) (\(name))"
                    } else {
                        "adding \(id)"
                    }
                case .removing(let id, let name):
                    if let name {
                        "removing \(id) (\(name))"
                    } else {
                        "removing \(id)"
                    }
                case .deinit: "deinit"
                }
            }
        }

        /// Events related to presenting and popping navigation destinations.
        nonisolated public enum NavigationEvent {
            case presenting(any NavigationDestination)
            case pushing(any Hashable)
            case popping
            case dismissed
        }

        /// Events related to resolving provided views.
        nonisolated public enum ProvidingEvent {
            case destination(any NavigationDestination)
        }

        /// Events related to navigation send/receive sequences.
        nonisolated public enum SendEvent {
            case performing(any Hashable)
            case sending(any Hashable)
            case receiving(any Hashable)
        }

        /// Events related to adding and returning to checkpoints.
        nonisolated public enum CheckpointEvent {
            case adding(String)
            case removing(String)
            case returning(String)
            case returningWithValue(String, Any)
        }

    }

}
