//
//  DarwinNotificationCenter.swift
//
//  Created by Nonstrict on 2023-12-07.
//

import Foundation
import Combine

private let center = CFNotificationCenterGetDarwinNotifyCenter()

/// Wrapper around the application’s Darwin notification center from CFNotificationCenter.h
///
/// - Note: On macOS, consider using DistributedNotificationCenter instead
final class DarwinNotificationCenter {
    private init() {}

    /// The application’s Darwin notification center.
    static var shared = DarwinNotificationCenter()

    /// Posts a Darwin notification with the specified name.
    func post(name: String) {
        CFNotificationCenterPostNotification(center, CFNotificationName(rawValue: name as CFString), nil, nil, true)
    }

    /// Registers an observer closure for Darwin notifications of the specified name.
    ///
    /// Retain the returned `DarwinNotificationObservation` to keep the observer active.
    ///
    /// Save the returned value in a variable, or store it in a bag.
    ///
    /// ```
    /// observation.store(in: &disposeBag)
    /// ```
    ///
    /// To stop observing the notifiation, deallocate the `DarwinNotificationObservation`, or call its `cancel()` method.
    func addObserver(name: String, callback: @escaping () -> Void) -> DarwinNotificationObservation {
        let observation = DarwinNotificationObservation(callback: callback)

        let pointer = UnsafeRawPointer(Unmanaged.passUnretained(observation.closure).toOpaque())

        CFNotificationCenterAddObserver(center, pointer, notificationCallback, name as CFString, nil, .deliverImmediately)

        return observation
    }
}

private func notificationCallback(center: CFNotificationCenter?, observation: UnsafeMutableRawPointer?, name: CFNotificationName?, object _: UnsafeRawPointer?, userInfo _: CFDictionary?) {
    guard let pointer = observation else { return }

    let closure = Unmanaged<DarwinNotificationObservation.Closure>.fromOpaque(pointer).takeUnretainedValue()

    closure.invoke()
}

/// Object that retains an observation of Darwin notifications.
///
/// Retain this object to keep the observer active.
///
/// Save this object in a variable, or store it in a bag.
///
/// ```
/// observation.store(in: &disposeBag)
/// ```
///
/// To stop observing the notifiation, deallocate the this object, or call the `cancel()` method.
final class DarwinNotificationObservation: Cancellable {
    // Wrapper class around the callback closure.
    // This object can stay alive in the cancel block, after this Observation has been deallocated.
    fileprivate class Closure {
        let invoke: () -> Void
        init(callback: @escaping () -> Void) {
            self.invoke = callback
        }
    }
    fileprivate let closure: Closure

    fileprivate init(callback: @escaping () -> Void) {
        self.closure = Closure(callback: callback)
    }

    deinit {
        cancel()
    }

    /// Cancels the Darwin notification observation.
    func cancel() {

        // Notifications are always delivered on the main thread.
        // So we also remove the observer on the main thread,
        // to make sure the closure object isn't deallocated during the execution of a notification.
        DispatchQueue.main.async { [closure] in
            let pointer = UnsafeRawPointer(Unmanaged.passUnretained(closure).toOpaque())
            CFNotificationCenterRemoveObserver(center, pointer, nil, nil)
        }
    }
}

// MARK: - AsyncSequence

extension DarwinNotificationCenter {

    /// Returns an asynchronous sequence of notifications for a given notification name.
    func notifications(named name: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let observation = addObserver(name: name) {
                continuation.yield()
            }
            continuation.onTermination = { _ in
                observation.cancel()
            }
        }
    }
}

// MARK: - Combine

#if canImport(Combine)

extension DarwinNotificationCenter {

    /// Returns a publisher that emits events when broadcasting notifications.
    ///
    /// - Parameters:
    ///   - name: The name of the notification to publish.
    /// - Returns: A publisher that emits events when broadcasting notifications.
    func publisher(for name: String) -> DarwinNotificationCenter.Publisher {
        Publisher(center: self, name: name)
    }
}

extension DarwinNotificationCenter {

    /// A publisher that emits when broadcasting notifications.
    struct Publisher: Combine.Publisher {
        typealias Output = Void
        typealias Failure = Never
        let center: DarwinNotificationCenter
        let name: String
        init(center: DarwinNotificationCenter, name: String) {
            self.center = center
            self.name = name
        }

        func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Never, S.Input == Output {
            let observation = center.addObserver(name: name) {
                _ = subscriber.receive()
            }

            subscriber.receive(subscription: observation)
        }
    }
}

extension DarwinNotificationObservation: Subscription {
    func request(_ demand: Subscribers.Demand) {
    }
}

#endif
