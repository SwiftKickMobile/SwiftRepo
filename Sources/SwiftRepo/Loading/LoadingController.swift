//
//  Created by Timothy Moose on 1/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Core

/// A state machine for loading, loaded, error and empty states.
public final actor LoadingController<DataType> where DataType: Emptyable {
    
    // MARK: - API

    /// Publishes the loading state on the main actor.
    @MainActor
    public private(set) lazy var state: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()

    /// The data loading states.
    public enum State: CustomStringConvertible {
        /// An initial loading state when there is no data to display. Components are responsible for displaying their own UI,
        /// if they choose to do so, when updating after initial data has already been loaded. For example, a list view may display
        /// a "pull-to-refresh" UI until the next state transition.
        ///
        /// When using `LoadingBehavior` with `delay > 0`, the `isHidden`
        /// flag is initially `true` meaning that loading state should not be displayed.  After `delay`,
        /// if still in the `.loading`, the `isHidden` flag is changed to `false` meaning the loading state should be displayed.
        case loading(isHidden: Bool)
        /// A state of having data to display. If there is an error while updating, after initial data is loaded, a new state is
        /// emitted with the previous data along with an error. Since there is data to display, the component would typically
        /// display an error banner.
        case loaded(DataType, Error?, isUpdating: Bool)
        /// A state of having no data to display, either because the initial load failed or returned empty results or because an
        /// update returned empty results.
        case empty(Error?)

        public var description: String {
            switch self {
            case let .loading(isHidden):
                return ".loading isHidden=\(isHidden)"
            case let .loaded(data, error, isUpdating):
                return ".loaded(\(data), \(String(describing: error)), \(isUpdating))"
            case let .empty(error):
                return ".empty(\(String(describing: error)))"
            }
        }

        /// View models should use this to establish the initial loading state, rather than dealing with an optional state.
        public static var initial: Self {
            .loading(isHidden: true)
        }
    }

    /// An alias for tasks that return data
    public typealias TaskType = Task<DataType, Error>

    /// The result type for consuming data and errors.
    public typealias ResultType = Result<DataType, Error>

    public struct LoadingBehavior {
        /// - Parameters:
        ///   - delay: The loading time which must elapse before the loading state is displayed.
        ///   - minimumDuration: The minimum amount of time the loading state will be displayed regardless of actual load time.
        ///   - loadedErrorsToEmpty: Bool value that, in the event an error is received while the current `LoadingController.LoadState`
        ///    is `loaded`, determines whether to set the new `LoadingController.LoadState` to a `loaded` state containing the error
        ///    (`loadedErrorsToEmpty` set to `false`) or an `empty` state containing the error (`loadedErrorsToEmpty` set to `true`).
        ///    Default behavior is `loadedErrorsToEmpty` set to `false`.
        ///    Example reason for setting `loadedErrorsToEmpty` to `true`: If an error is received during a type ahead search, we do not want to
        ///    show results that do not match the user's search term and we also do not want to revert the user's search term back to the last successful
        ///    search term. In this scenario, it is more reasonable to consider this a search with empty results and an error.
        public init(delay: Duration, minimumDuration: Duration, loadedErrorsToEmpty: Bool = false) {
            self.delay = delay
            self.minimumDuration = minimumDuration
            self.loadedErrorsToEmpty = loadedErrorsToEmpty
        }

        public init(delay: Double, minimumDuration: Double, loadedErrorsToEmpty: Bool = false) {
            self.delay = .seconds(delay)
            self.minimumDuration = .seconds(minimumDuration)
            self.loadedErrorsToEmpty = loadedErrorsToEmpty
        }

        public var delay: Duration
        public var minimumDuration: Duration
        public var loadedErrorsToEmpty: Bool
    }

    /// Called to inform the controller that data is being loaded or updated. Calling this at the appropriate time is essential to
    /// the behavior of the state machine.
    @MainActor
    public func loading() {
        switch loadState {
        case .none:
            indefiniteController?.start()
            set(state: .loading(isHidden: isLoadingHidden))
        case .loading:
            set(state: .loading(isHidden: isLoadingHidden))
        case .updating:
            indefiniteController?.prepareForReuse()
            indefiniteController?.start()
        case let .loaded(cachedData, _):
            indefiniteController?.prepareForReuse()
            indefiniteController?.start()
            set(state: .updating(cachedData: cachedData, isHidden: true))
        case .empty:
            indefiniteController?.prepareForReuse()
            indefiniteController?.start()
            set(state: .loading(isHidden: isLoadingHidden))
        }
    }

    /// Sets the result of loading or updating the data.
    @MainActor
    public func set(result: ResultType) {
        let newState = result.asLoadState(
            currentLoadState: loadState,
            loadedErrorsToEmpty: loadingBehavior?.loadedErrorsToEmpty ?? false
        )
        if indefiniteController == nil || indefiniteController?.tryStoppingSynchronously() == true {
            set(state: newState)
        } else {
            // TODO: can this be made an `async` function to avoid the embedded `Task`?
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.indefiniteController?.stop()
                self.set(state: newState)
            }
        }
    }

    /// A subscriber than can receive the published results of loading or updating the data.
    @MainActor
    public private(set) lazy var resultSubscriber: AnySubscriber<ResultType, Never> = {
        resultSubject
            // TODO: this is a liability, but embedding a main actor task breaks the synchronous data pipeline. Probably need to move to `AsyncSequence`
            .sink { [weak self] in self?.set(result: $0) }
            .store(in: &cancellables)
        return AnySubscriber(resultSubject)
    }()

    /// Reset the LoadingController to the default state, so that a fresh load can be triggered. Cancels any active task.
    @MainActor
    public func reset() {
        task?.cancel()
        task = nil
        loadState = .none
        isLoadingHidden = loadingBehavior.map { $0.delay > .zero } ?? false
        stateSubject.send(.loading(isHidden: isLoadingHidden))
        indefiniteController?.prepareForReuse()
    }

    /// Create a loading controller.
    /// - Parameters:
    ///   - loadingBehavior: the indefinite loading behavior, if any (see `IndefiniteController`.
    ///   - data: the initial data, if any. Supplying initial data, such as through pre-fetching or caching,
    ///   allows content to be displayed synchronously for maximum UI responsiveness.
    @MainActor
    public init(
        loadingBehavior: LoadingBehavior? = nil,
        data: DataType? = nil
    ) {
        self.loadingBehavior = loadingBehavior
        installIndefiniteController()

        reset()

        if let data = data {
            actorSet(data: data)
        }
    }

    // MARK: - Constants

    private typealias VoidTaskType = Task<Void, Error>

    /// The private state of the controller, more granular than the public state.
    fileprivate enum LoadState {
        /// The initial state of the controller.
        case none

        /// The controller is loading for the first time, showing a loading state.
        case loading(isHidden: Bool)

        /// The controller is refreshing. Instead of a loading state, the data from the previous load is displayed. Typically, this state
        /// is associated with a refresh action in the UI, such as pull-to-refresh.
        case updating(cachedData: DataType, isHidden: Bool)

        /// The data has been loaded and is being displayed.
        case loaded(data: DataType, error: Error?)

        /// The data failed to load or was empty and an empty state is being displayed. When there is an error with `updating`,
        /// the controller transitions back to `loaded` rather than `empty`, assuming the UI should continue to display
        /// the cached data while displaying an appropriate error message to the user.
        case empty(error: Error?)

        /// Returns loaded data, if any.
        var data: DataType? {
            switch self {
            case .none: return nil
            case .loading: return nil
            case let .updating(cachedData, _): return cachedData
            case let .loaded(data, _): return data
            case .empty: return nil
            }
        }
    }

    enum LoadingControllerError: Error, CaseIterable {
        case transitionToNone
        case transitionToLoading
        case transitionToUpdating
    }

    // MARK: - Variables

    @MainActor
    private var indefiniteController: IndefiniteController?
    @MainActor
    private var isLoadingHidden = true
    @MainActor
    let resultSubject = PassthroughSubject<ResultType, Never>()
    /// This needs to be made lazy in order to be `nonisolated`.
    private nonisolated lazy var cancellables = Set<AnyCancellable>()

    @MainActor
    public let stateSubject = CurrentValueSubject<State, Never>(.loading(isHidden: true))

    @MainActor
    private var task: TaskType? {
        didSet {
            oldValue?.cancel()
        }
    }

    @MainActor
    private var loadState: LoadState = .none

    @MainActor

    private let loadingBehavior: LoadingBehavior?

    // MARK: - State machine

    // I really don't see how breaking this state machine logic into
    // smaller chunks improves anything: swiftlint:disable cyclomatic_complexity
    @MainActor
    private func set(state: LoadState) {
        let oldValue = loadState
        loadState = state
        // Determine if there's data to display and initiate the appropriate transition.
        // And do other stuff specific to the given state.
        switch state {
        case .none:
            assertionFailure(LoadingControllerError.transitionToNone.localizedDescription)
            break
        case .loading:
            switch oldValue {
            case .loaded, .updating:
                assertionFailure(LoadingControllerError.transitionToLoading.localizedDescription)
                break
            case let .loading(isHidden):
                if isHidden != isLoadingHidden {
                    stateSubject.send(.loading(isHidden: isLoadingHidden))
                }
            case .none, .empty:
                stateSubject.send(.loading(isHidden: isLoadingHidden))
            }
        case let .updating(cachedData, isHidden):
            switch oldValue {
            case .none, .loading:
                assertionFailure(LoadingControllerError.transitionToUpdating.localizedDescription)
                break
            case let .updating(_, oldIsHidden):
                if isHidden != oldIsHidden {
                    stateSubject.send(.loaded(cachedData, nil, isUpdating: !isHidden))
                }
            case .loaded:
                break
            case .empty:
                stateSubject.send(.loading(isHidden: isLoadingHidden))
            }
        case let .loaded(data, error):
            task = nil
            stateSubject.send(.loaded(data, error, isUpdating: false))
        case let .empty(error):
            task = nil
            stateSubject.send(.empty(error))
        }
    }

    // MARK: - Loading the data

    // Legacy support for the old task-based loading.
    @MainActor
    private func internalLoad(task: TaskType) async {
        self.task = task
        loading()
        let result: ResultType
        do {
            let data = try await task.value
            guard task.isCancelled != true else { return }
            result = .success(data)
        } catch {
            // This logic deals with internal cancellations. If cancelled externally, the canceller is responsible
            // for any UI updates.
            guard !task.isCancelled else { return }
            result = .failure(error)
        }
        let newState = result.asLoadState(
            currentLoadState: loadState,
            loadedErrorsToEmpty: loadingBehavior?.loadedErrorsToEmpty ?? false
        )
        await indefiniteController?.stop()
        guard !task.isCancelled else { return }
        set(state: newState)
        if self.task == task {
            self.task = nil
        }
    }

    @MainActor
    private func installIndefiniteController() {
        if let loadingBehavior = loadingBehavior {
            indefiniteController = IndefiniteController(
                delay: loadingBehavior.delay,
                minimumDuration: loadingBehavior.minimumDuration,
                delegate: self
            )
        }
    }
}

// MARK: Mutating actor isolated state

extension LoadingController {
    @MainActor
    private func actorSet(task: TaskType?) {
        self.task = task
    }

    @MainActor
    private func actorSet(isLoadingHidden: Bool) async {
        self.isLoadingHidden = isLoadingHidden
    }

    @MainActor
    private func actorSet(loadState: LoadState) {
        self.loadState = loadState
    }

    @MainActor
    private func actorStateSubjectSend(state: State) {
        stateSubject.send(state)
    }

    @MainActor
    private func actorSet(data: DataType) {
        actorSet(loadState: .loaded(data: data, error: nil))
        actorStateSubjectSend(state: .loaded(data, nil, isUpdating: false))
    }
}

// MARK: IndefiniteControllerDelegate

extension LoadingController: IndefiniteControllerDelegate {
    public nonisolated func didExceedDelayChanged(_ didExceedDelay: Bool) {
        let isLoadingHidden = !didExceedDelay
        Task { @MainActor in
            self.isLoadingHidden = isLoadingHidden
            switch loadState {
            case let .loading(isHidden) where isHidden != isLoadingHidden:
                set(state: .loading(isHidden: isLoadingHidden))
            case let .updating(cachedData, isHidden) where isHidden != isLoadingHidden:
                set(state: .updating(cachedData: cachedData, isHidden: isLoadingHidden))
            default: break
            }
        }
    }
}

extension LoadingController.State: Equatable where DataType: Equatable {
    /// Sadly, must write this out because `Error` isn't `Equatable`
    public static func == (lhs: LoadingController<DataType>.State, rhs: LoadingController<DataType>.State) -> Bool {
        switch (lhs, rhs) {
        case let (.loading(lhs), .loading(rhs)):
            return lhs == rhs
        case let (.loaded(lDataType, lError, lIsUpdating), .loaded(rDataType, rError, rIsUpdating)):
            return lDataType == rDataType && (lError as NSError?) == (rError as NSError?) && lIsUpdating == rIsUpdating
        case let (.empty(lError), .empty(rError)):
            return (lError as NSError?) == (rError as NSError?)
        default: return false
        }
    }
}

private extension Result where Success: Emptyable {
    @MainActor
    func asLoadState(
        currentLoadState: LoadingController<Success>.LoadState,
        loadedErrorsToEmpty: Bool = false
    ) -> LoadingController<Success>.LoadState {
        switch self {
        case let .success(data):
            switch data.isEmpty {
            case true: return .empty(error: nil)
            case false: return .loaded(data: data, error: nil)
            }
        case let .failure(error):
            switch currentLoadState.data {
            case let data?: return loadedErrorsToEmpty ? .empty(error: error) : .loaded(data: data, error: error)
            case .none: return .empty(error: error)
            }
        }
    }
}

extension LoadingController.LoadingControllerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .transitionToNone: return "Invalid transition to .none state"
        case .transitionToLoading: return "Invalid transition to .loading state from .loaded or .updating"
        case .transitionToUpdating: return "Invalid transition to .updating state from .none or .loading"
        }
    }
}
