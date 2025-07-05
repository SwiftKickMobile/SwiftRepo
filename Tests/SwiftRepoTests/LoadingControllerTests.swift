//
//  Created by Timothy Moose on 1/28/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Testing
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct LoadingControllerTests {
    
    // MARK: - Constants
    
    enum Data: Emptyable, Equatable, Error {
        case empty
        case one
        case two
        case three
        
        var isEmpty: Bool {
            switch self {
            case .empty:
                return true
            case .one, .two, .three:
                return false
            }
        }
    }
    
    struct ScheduledTask {
        let delay: TimeInterval
        let task: Task<Data, Error>
        
        init(delay: TimeInterval, task: Task<Data, Error>) {
            self.delay = delay
            self.task = task
        }
    }
    
    // MARK: - Tests
    
    @Test("Initial state")
    func initial() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController<Data>())
        #expect(testState.transitions == [])
    }
    
    @Test("Load empty")
    func loadEmpty() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController<Data>())
        testState.tasks = [
            ScheduledTask(delay: 0, task: Task { Data.empty }),
        ]
        await testState.performTask()
        try? await Task.sleep(for: .seconds(0.1))
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .empty(nil),
        ])
    }
    
    @Test("Load")
    func load() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController<Data>())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
        ]
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Load fast")
    func loadFast() async {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController<Data>(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { Data.one }),
        ]
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Load slow")
    func loadSlow() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        testState.tasks = [
            ScheduledTask(delay: 0.15, task: Task { Data.one }),
        ]
        await testState.performTask()
        try await testState.arbitraryWait()
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Load subscriber fast")
    func loadSubscriberFast() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        testState.controller.loading()
        try await Task.sleep(for: .seconds(0.05))
        testState.resultSubject.send(.success(.one))
        testState.resultSubject.send(.success(.two))
        try await Task.sleep(for: .seconds(0.05))
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Load subscriber slow")
    func loadSubscriberSlow() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        testState.controller.loading()
        try await Task.sleep(for: .seconds(0.15))
        testState.resultSubject.send(.success(.one))
        try await Task.sleep(for: .seconds(0.1))
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Reset")
    func reset() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { Data.two }),
        ]
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
        testState.controller.reset()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
        ])
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
        ])
        testState.controller.reset()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
            .loading(isHidden: false),
        ])
    }
    
    @Test("Update")
    func update() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { Data.two }),
        ]
        await testState.performTask()
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Set")
    func set() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.controller.set(result: .success(.one))
        #expect(testState.transitions == [
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Set subscriber")
    func setSubscriber() async throws {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        testState.resultSubject.send(.success(.one))
        testState.resultSubject.send(.success(.two))
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        #expect(testState.transitions == [
            .empty(TestError(category: .failure)),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.two, TestError(category: .failure), isUpdating: false),
        ])
    }
    
    @Test("Set subscriber loading")
    func setSubscriberLoading() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.controller.loading()
        testState.resultSubject.send(.success(.one))
        testState.controller.loading()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Set subscriber loaded")
    func setSubscriberLoaded() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.resultSubject.send(.success(.one))
        testState.controller.loading()
        testState.resultSubject.send(.success(.two))
        #expect(testState.transitions == [
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Set subscriber all states")
    func setSubscriberAllStates() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.controller.loading()
        testState.resultSubject.send(.success(.empty))
        testState.controller.loading()
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        testState.controller.loading()
        testState.resultSubject.send(.success(.one))
        testState.controller.loading()
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        testState.controller.loading()
        testState.resultSubject.send(.success(.two))
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .empty(nil),
            .loading(isHidden: false),
            .empty(TestError(category: .failure)),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, TestError(category: .failure), isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Set subscriber all states async")
    func setSubscriberAllStatesAsync() async throws {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        try await Task.sleep(for: .seconds(0.1))
        testState.controller.loading()
        testState.resultSubject.send(.success(.empty))
        testState.controller.loading()
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        testState.controller.loading()
        testState.resultSubject.send(.success(.one))
        testState.controller.loading()
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        testState.controller.loading()
        testState.resultSubject.send(.success(.two))
        try await Task.sleep(for: .seconds(0.1))
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .empty(nil),
            .loading(isHidden: false),
            .empty(TestError(category: .failure)),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, TestError(category: .failure), isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Set subscriber loaded error to empty error")
    func setSubscriberLoadedErrorToEmptyError() async {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.1, loadedErrorsToEmpty: true)
            )
        )
        testState.controller.loading()
        testState.resultSubject.send(.success(.one))
        testState.controller.loading()
        testState.resultSubject.send(.failure(TestError(category: .failure)))
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .empty(TestError(category: .failure)),
        ])
    }
    
    @Test("Set cancel")
    func setCancel() async throws {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
        ]
        async let load: Void = await testState.performTask()
        async let set = Task {
            try await Task.sleep(for: .seconds(0.05))
            await testState.controller.set(result: .success(.two))
        }
        _ = try await (load, set.value)
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Load cancel")
    func loadCancel() async throws {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { Data.two }),
        ]
        async let load1: Void = await testState.performTask()
        async let load2 = Task {
            try await Task.sleep(for: .seconds(0.05))
            await testState.performTask()
        }
        _ = try await (load1, load2.value)
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Update cancel")
    func updateCancel() async throws {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { Data.two }),
            ScheduledTask(delay: 0.1, task: Task { Data.three }),
        ]
        await testState.performTask()
        async let load1: Void = await testState.performTask()
        async let load2 = Task {
            try await Task.sleep(for: .seconds(0.05))
            await testState.performTask()
        }
        _ = try await (load1, load2.value)
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.three, nil, isUpdating: false),
        ])
    }
    
    @Test("Empty")
    func empty() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.empty }),
        ]
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .empty(nil),
        ])
    }
    
    @Test("Empty error")
    func emptyError() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .empty(Data.one),
        ])
    }
    
    @Test("Loaded error")
    func loadedError() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await testState.performTask()
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, Data.one, isUpdating: false),
        ])
    }
    
    @Test("Loaded error to empty error")
    func loadedErrorToEmptyError() async {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.1, loadedErrorsToEmpty: true)
            )
        )
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await testState.performTask()
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .empty(Data.one),
        ])
    }
    
    @Test("Empty loaded")
    func emptyLoaded() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.2)
            )
        )
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.empty }),
            ScheduledTask(delay: 0.3, task: Task { Data.one }),
        ]
        await testState.performTask()
        await testState.performTask()
        try await testState.arbitraryWait()
        try await testState.arbitraryWait()
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .empty(nil),
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @Test("Loaded empty")
    func loadedEmpty() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
            ScheduledTask(delay: 0.1, task: Task { Data.empty }),
        ]
        await testState.performTask()
        await testState.performTask()
        #expect(testState.transitions == [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .empty(nil),
        ])
    }
    
    @Test("Loaded updating")
    func loadedUpdating() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { Data.one }),
            ScheduledTask(delay: 0.15, task: Task { Data.two }),
        ]
        await testState.performTask()
        await testState.performTask()
        try await testState.arbitraryWait()
        #expect(testState.transitions == [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, nil, isUpdating: true),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @Test("Loaded error retry same error")
    func loadedErrorRetrySameError() async {
        let testState = TestState()
        testState.setUp(controller: LoadingController())
        
        // Initial successful load
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { Data.one }),
        ]
        await testState.performTask()
        
        // First error
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        
        // Clear transitions so we can focus on the retry scenario
        testState.transitions.removeAll()
        
        // Retry with the same error
        testState.tasks = [
            ScheduledTask(delay: 0.1, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        
        // The key test: when retrying from a loaded error state, we should see:
        // 1. An intermediate state clearing the error (loaded with nil error, isUpdating: false)
        // 2. Then the new error state
        // This ensures SwiftUI detects the state change even when the same error occurs
        #expect(testState.transitions == [
            .loaded(.one, nil, isUpdating: false),  // Error cleared on retry
            .loaded(.one, TestError(category: .failure), isUpdating: false),  // Same error, but detected as change
        ])
    }

    @Test("Loaded error retry same error with loading behavior")
    func loadedErrorRetrySameErrorWithLoadingBehavior() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        
        // Initial successful load
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { Data.one }),
        ]
        await testState.performTask()
        
        // First error
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        
        // Clear transitions so we can focus on the retry scenario
        testState.transitions.removeAll()
        
        // Retry with the same error (slow completion - exceeds delay)
        testState.tasks = [
            ScheduledTask(delay: 0.15, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        try await testState.arbitraryWait()
        
        // With loading behavior and slow retry, we should see:
        // 1. Error cleared initially with isUpdating: false 
        // 2. When delay exceeded, isUpdating: true
        // 3. Error state with isUpdating: false (final state)
        #expect(testState.transitions == [
            .loaded(.one, nil, isUpdating: false),  // Error cleared on retry
            .loaded(.one, nil, isUpdating: true),   // Delay exceeded, isUpdating: true
            .loaded(.one, TestError(category: .failure), isUpdating: false),  // Same error, but detected as change
        ])
    }

    @Test("Loaded error retry same error with loading behavior fast")
    func loadedErrorRetrySameErrorWithLoadingBehaviorFast() async throws {
        let testState = TestState()
        testState.setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        
        // Initial successful load
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { Data.one }),
        ]
        await testState.performTask()
        
        // First error
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        
        // Clear transitions so we can focus on the retry scenario
        testState.transitions.removeAll()
        
        // Retry with the same error (fast completion - doesn't exceed delay)
        testState.tasks = [
            ScheduledTask(delay: 0.05, task: Task { throw TestError(category: .failure) }),
        ]
        await testState.performTask()
        try await testState.arbitraryWait()
        
        // With loading behavior but fast retry, we should see:
        // 1. Error cleared with isUpdating: false (because delay not exceeded)
        // 2. Error state with isUpdating: false (final state)
        #expect(testState.transitions == [
            .loaded(.one, nil, isUpdating: false),  // Error cleared on retry, isUpdating: false (delay not exceeded)
            .loaded(.one, TestError(category: .failure), isUpdating: false),  // Same error, but detected as change
        ])
    }
}

// MARK: - Test State Helper

@MainActor
private class TestState {
    typealias ControllerType = LoadingController<LoadingControllerTests.Data>
    typealias ResultType = Result<LoadingControllerTests.Data, Error>
    
    var transitions: [ControllerType.State] = []
    var tasks: [LoadingControllerTests.ScheduledTask] = []
    var controller: ControllerType!
    var resultSubject: PassthroughSubject<ResultType, Never>!
    private var cancellables = Set<AnyCancellable>()
    private var taskProducer: (() -> ControllerType.TaskType)!
    
    init() {
        taskProducer = {
            let scheduledTask = self.tasks.removeFirst()
            return Task {
                try await Task.sleep(for: .seconds(scheduledTask.delay))
                return try await scheduledTask.task.value
            }
        }
        resultSubject = PassthroughSubject<ResultType, Never>()
    }
    
    func setUp(controller: ControllerType) {
        self.controller = controller
        controller.state
            .dropFirst()
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
        
        resultSubject.receive(subscriber: controller.resultSubscriber)
    }
    
    private var state: ControllerType.State = .loading(isHidden: true) {
        didSet {
            transitions.append(state)
        }
    }
    
    func performTask() async {
        controller.loading()
        let result = await taskProducer().result
        switch result {
        case .success(let data):
            controller.set(result: .success(data))
        case .failure(let error):
            controller.set(result: .failure(error))
        }
    }
    
    /// Waits for a somewhat arbitrary amount of time, giving the publisher a beat to update the state properly.
    /// If tests unexpectedly fail, first try bumping this value up a bit.
    func arbitraryWait() async throws {
        try await Task.sleep(for: .seconds(0.1))
    }
}
