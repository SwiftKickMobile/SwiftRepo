//
//  Created by Timothy Moose on 1/28/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import QuartzCore
import OSLog

/// The user of `IndefiniteController` adapts this protocol to receive `isDelaying` change notifications.
/// (Note, we couldn't figure out how to achieve this using a publisher when the user was another actor.)
public protocol IndefiniteControllerDelegate: AnyObject {
    /// Informs the delegate that the controller is "running", which means the delay peried has been exceeded and the
    /// controller will run for the minimum duration.
    /// - Parameter isRunning: `true` if the controller is "running"
    func didExceedDelayChanged(_ didExceedDelay: Bool)
}

/// A state machine for indefinite processes, in particular indefinite loading.
///
/// Indefinite loading is a UX refinement that brings the following logic to loading states:
/// 1. If the data loads faster than some specified `delay`, the data will be displayed, bypassing the loading state.
/// 2. If the data loads slower than `delay`, the loading state will be displayed for a guaranteed `minimumDuration`.
///
/// The user calls `start()` before initiating the indefinite process, e.g. before loading content. If the controller transitions
/// to delaying state, i.e. the time is less than `delay`, the user should hide the loading state.
///
/// When the indefinite process is finished, e.g. the content is downloaded, the
/// user waits for the indefinite controller to finish by awaiting `stop()`. If the time is less than `delay`, `stop()`
/// will complete immediately. If the time is greater than `delay`, `stop()` will complete as soon as the time is
/// greater than `delay + minimumDuration`.
///
/// When `stop()` is completed, the user may transition away from the loading state.
public final actor IndefiniteController {
    
    // MARK: - API

    public typealias DidExceedDelay = (Bool) -> Void

    public init(
        delay: Duration,
        minimumDuration: Duration,
        delegate: IndefiniteControllerDelegate? = nil,
        didExceedDelay: DidExceedDelay? = nil
    ) {
        self.delay = delay
        self.minimumDuration = minimumDuration
        self.delegate = delegate
        self.didExceedDelay = didExceedDelay
    }

    @MainActor
    public func set(delegate: IndefiniteControllerDelegate) {
        self.delegate = delegate
    }

    /// Called before view is reused, e.g. in a table or collection view in order to reset
    /// the content. Call this before the first use to ensure the proper initial state.
    @MainActor
    public func prepareForReuse() {
        logInfo(message: "prepareForReuse() called")
        startID = nil
        startTime = nil
        state = .stopped
        logInfo(message: "prepareForReuse() stopped")
    }

    @MainActor
    public func start() {
        logInfo(message: "start() called")
        guard state == .stopped else { return }
        let startID = UUID()
        self.startID = startID
        guard delay > .zero else {
            state = .running
            startTime = ContinuousClock.now
            logInfo(message: "start() started running")
            return
        }
        state = .delaying
        // Projected start time
        startTime = ContinuousClock.now.advanced(by: delay)
        logInfo(message: "start() started delaying")
        delayedStart(remainingDelay: delay, startID: startID)
    }

    /// Attempts to stop syncrhonously if the current state meets the required conditions.
    /// - Returns: `true` if successfully stoped. Otherwise, no change is made and it is still necessary to call `stop()`.
    @MainActor
    public func tryStoppingSynchronously() -> Bool {
        logInfo(message: "tryStoppingSynchronously() called")
        switch state {
        case .stopped:
            return true
        case .delaying:
            state = .stopped
            logInfo(message: "tryStoppingSynchronously() set state")
            return true
        case .running, .stopping:
            return false
        }
    }

    /// Stops the indefinite process. If have been shown less than `minimum` seconds, then stopping
    /// is delayed by the time needed to reach `minimum`. Otherwise, hiding occurs immediately.
    /// Returns when state is set to `stopped`.
    @MainActor
    public func stop() async {
        logInfo(message: "stop() called")
        switch state {
        case .stopped:
            return
        case .delaying:
            state = .stopped
            return
        // For .running and .stopping, await delayedStop
        case .running, .stopping:
            guard let startTime = startTime else {
                assertionFailure()
                return
            }
            state = .stopping
            let elapsed = ContinuousClock.now - startTime
            let remainder = minimumDuration - elapsed
            await delayedStop(remainingDelay: remainder)
        }
        logInfo(message: "stop() set state")
    }

    // MARK: - Constants

    /// The various states of the indefinite process.
    private enum State: String {
        /// Controller is in the default state, ready to be started.
        case stopped
        /// Controller is started and within the delay period.
        case delaying
        /// Controller has exceeded the delay period and will run for at least the minimum duration.
        case running
        /// Stop has been called while the controller is running and has not reached the minimum duration yet.
        case stopping

        /// Controller has exceeded the delay period and must run for the minimum duration.
        var didExceedDelay: Bool {
            self == .running || self == .stopping
        }
    }

    private let sleepTolerance: Duration = .seconds(0.001)

    // MARK: - Variables

    @MainActor
    private var startID: UUID?
    @MainActor
    private var startTime: ContinuousClock.Instant?
    private let logger = Logger(subsystem: "Loading", category: "IndefiniteController")
    private let referenceInstance = ContinuousClock.now

    @MainActor
    private let didExceedDelay: DidExceedDelay?

    @MainActor
    private weak var delegate: IndefiniteControllerDelegate?

    /// Specifies how long to wait after `start()` before the state is set to
    /// `running`. If the indefinite task takes less time than `delay`, one
    /// should not display a loading state for the relevant view.
    private let delay: Duration

    /// Specifies the minumum amount of time the process should be considered
    /// as running before the state is set to `stopped`. If the indefinite task's runtime
    /// surpasses `delay`, `minimum` run time will take effect.
    private let minimumDuration: Duration

    /// The current state
    @MainActor
    private var state: State = .stopped {
        didSet {
            guard state.didExceedDelay != oldValue.didExceedDelay else { return }
            logInfo(message: "didExceedDelayChanged \(state.didExceedDelay)")
            delegate?.didExceedDelayChanged(state.didExceedDelay)
            didExceedDelay?(state.didExceedDelay)
        }
    }

    // MARK: - Helpers

    /// Returns when state is set to `running`
    @MainActor
    private func delayedStart(remainingDelay: Duration, startID: UUID) {
        logInfo(message: "delayedStart() called with remainingDelay=\(remainingDelay)")
        guard state == .delaying, let startTime = startTime, startID == self.startID else { return }

        guard remainingDelay > .zero else {
            self.startTime = ContinuousClock.now
            state = .running
            return
        }

        Task { @MainActor in
            logInfo(message: "delayedStart() sleeping")
            try? await Task.sleep(for: remainingDelay, tolerance: sleepTolerance)
            guard state == .delaying,
                  // Make sure `prepareForReuse()` wasn't called while we were asleep.
                  self.startID == startID else { return }

            // Start time can be updated during delay.
            let updatedRemainingDelay = startTime - ContinuousClock.now
            guard updatedRemainingDelay <= .zero else {
                delayedStart(remainingDelay: updatedRemainingDelay, startID: startID)
                return
            }
            logInfo(message: "delayedStart() set state")
            self.startTime = ContinuousClock.now
            state = .running
        }
    }

    /// Returns when state is set to `stopped`
    @MainActor
    private func delayedStop(remainingDelay: Duration) async {
        logInfo(message: "delayedStop() called with remainingDelay=\(remainingDelay)")
        guard state == .stopping else {
            switch state {
            case .running:
                logInfo(message: "delayedStop() encountered .running state")
                // Can transition back to running if update performed
                // while stopping. Completion block will not be called.
                return
            default:
                assertionFailure()
                return
            }
        }
        guard remainingDelay > .zero else {
            state = .stopped
            logInfo(message: "delayedStop() set state")
            return
        }

        try? await Task.sleep(for: remainingDelay, tolerance: sleepTolerance)
        guard state == .stopping else { return }
        guard let startTime = startTime else {
            assertionFailure()
            return
        }
        // Start time can change during delay
        let elapsed = ContinuousClock.now - startTime
        let newRemainingDelay = minimumDuration - elapsed
        guard newRemainingDelay <= .zero else {
            await delayedStop(remainingDelay: newRemainingDelay)
            return
        }
        state = .stopped
        logInfo(message: "delayedStop() set state")
    }

    @MainActor
    private func logInfo(message: String) {
        let time = self.startTime.map { referenceInstance.duration(to: $0) }
        let timeFormat: Duration.TimeFormatStyle = .time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 3))
        logger.info("\(message): state=\(self.state.rawValue), startTime=\(time?.formatted(timeFormat) ?? "[none]"), startID=\(self.startID?.uuidString ?? "[none]")")
    }
}
