//
//  Created by Timothy Moose on 1/28/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import XCTest
import Core
import Test
@testable import SwiftRepo

class LoadingControllerTests: XCTestCase {
    
    // MARK: - Constants
    
    private struct ScheduledTask {
        var delay: TimeInterval
        var task: ControllerType.TaskType
    }
    
    private typealias ControllerType = LoadingController<Data>
    private typealias ResultType = Result<Data, Error>
    
    private enum Data: String, Error, Emptyable {
        case empty
        case one
        case two
        case three
        
        var isEmpty: Bool {
            self == .empty
        }
        
        var description: String {
            rawValue
        }
    }
    
    // MARK: - Variables
    
    private var transitions: [ControllerType.State] = []
    private var tasks: [ScheduledTask] = []
    private var controller: ControllerType!
    private var resultSubject: PassthroughSubject<ResultType, Never>!
    private var cancellables = Set<AnyCancellable>()
    private var taskProducer: (() -> ControllerType.TaskType)!
    
    // MARK: - Tests
    
    func testInitial() async {
        await setUp(controller: LoadingController())
        XCTAssertEqual(transitions, [])
    }
    
    func testLoadEmpty() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0, task: Task { .empty }),
        ]
        await performTask()
        try? await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .empty(nil),
        ])
    }
    
    func testLoad() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
        ]
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    
    func testLoadFast() async {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        tasks = [
            ScheduledTask(delay: 0.05, task: Task { .one }),
        ]
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    func testLoadSlow() async throws {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        tasks = [
            ScheduledTask(delay: 0.15, task: Task { .one }),
        ]
        await performTask()
        try await arbitraryWait()
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    func testLoadSubscriberFast() async throws {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        await controller.loading()
        try await Task.sleep(for: .seconds(0.05))
        resultSubject.send(.success(.one))
        resultSubject.send(.success(.two))
        try await Task.sleep(for: .seconds(0.05))
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    func testLoadSubscriberSlow() async throws {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        await controller.loading()
        try await Task.sleep(for: .seconds(0.15))
        resultSubject.send(.success(.one))
        try await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    func testReset() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { .two }),
        ]
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
        await controller.reset()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
        ])
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
        ])
        await controller.reset()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loading(isHidden: false),
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
            .loading(isHidden: false),
        ])
    }
    
    func testUpdate() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { .two }),
        ]
        await performTask()
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    func testSet() async {
        await setUp(controller: LoadingController())
        await controller.set(result: .success(.one))
        XCTAssertEqual(transitions, [
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @MainActor
    func testSetSubscriber() async throws {
        setUp(controller: LoadingController())
        resultSubject.send(.failure(TestError(category: .failure)))
        resultSubject.send(.success(.one))
        resultSubject.send(.success(.two))
        resultSubject.send(.failure(TestError(category: .failure)))
        XCTAssertEqual(transitions, [
            .empty(TestError(category: .failure)),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.two, TestError(category: .failure), isUpdating: false),
        ])
    }
    
    @MainActor
    func testSetSubscriberLoading() {
        setUp(controller: LoadingController())
        controller.loading()
        resultSubject.send(.success(.one))
        controller.loading()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    @MainActor
    func testSetSubscriberLoaded() {
        setUp(controller: LoadingController())
        resultSubject.send(.success(.one))
        controller.loading()
        resultSubject.send(.success(.two))
        XCTAssertEqual(transitions, [
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    @MainActor
    func testSetSubscriberAllStates() {
        setUp(controller: LoadingController())
        controller.loading()
        resultSubject.send(.success(.empty))
        controller.loading()
        resultSubject.send(.failure(TestError(category: .failure)))
        controller.loading()
        resultSubject.send(.success(.one))
        controller.loading()
        resultSubject.send(.failure(TestError(category: .failure)))
        controller.loading()
        resultSubject.send(.success(.two))
        XCTAssertEqual(transitions, [
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
    
    func testSetSubscriberAllStatesAsync() async throws {
        await setUp(controller: LoadingController())
        try await Task.sleep(for: .seconds(0.1))
        await controller.loading()
        resultSubject.send(.success(.empty))
        await controller.loading()
        resultSubject.send(.failure(TestError(category: .failure)))
        await controller.loading()
        resultSubject.send(.success(.one))
        await controller.loading()
        resultSubject.send(.failure(TestError(category: .failure)))
        await controller.loading()
        resultSubject.send(.success(.two))
        try await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(transitions, [
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
    
    @MainActor
    func testSetSubscriberLoadedErrorToEmptyError() {
        setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.1, loadedErrorsToEmpty: true)
            )
        )
        controller.loading()
        resultSubject.send(.success(.one))
        controller.loading()
        resultSubject.send(.failure(TestError(category: .failure)))
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .empty(TestError(category: .failure)),
        ])
    }
    
    func testSetCancel() async throws {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
        ]
        async let load: Void = await performTask()
        async let set = Task {
            try await Task.sleep(for: .seconds(0.05))
            await controller.set(result: .success(.two))
        }
        _ = try await (load, set.value)
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    func testLoadCancel() async throws {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { .two }),
        ]
        async let load1: Void = await performTask()
        async let load2 = Task {
            try await Task.sleep(for: .seconds(0.05))
            await performTask()
        }
        _ = try await (load1, load2.value)
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    func testUpdateCancel() async throws {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { .two }),
            ScheduledTask(delay: 0.1, task: Task { .three }),
        ]
        await performTask()
        async let load1: Void = await performTask()
        async let load2 = Task {
            try await Task.sleep(for: .seconds(0.05))
            await performTask()
        }
        _ = try await (load1, load2.value)
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.two, nil, isUpdating: false),
            .loaded(.three, nil, isUpdating: false),
        ])
    }
    
    func testEmpty() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .empty }),
        ]
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .empty(nil),
        ])
    }
    
    func testEmptyError() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .empty(Data.one),
        ])
    }
    
    func testLoadedError() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await performTask()
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, Data.one, isUpdating: false),
        ])
    }
    
    func testLoadedErrorToEmptyError() async {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.1, loadedErrorsToEmpty: true)
            )
        )
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { throw Data.one }),
        ]
        await performTask()
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .empty(Data.one),
        ])
    }
    
    func testEmptyLoaded() async throws {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.2, minimumDuration: 0.2)
            )
        )
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .empty }),
            ScheduledTask(delay: 0.3, task: Task { .one }),
        ]
        await performTask()
        await performTask()
        try await arbitraryWait()
        try await arbitraryWait()
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .empty(nil),
            .loading(isHidden: true),
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
        ])
    }
    
    func testLoadedEmpty() async {
        await setUp(controller: LoadingController())
        tasks = [
            ScheduledTask(delay: 0.1, task: Task { .one }),
            ScheduledTask(delay: 0.1, task: Task { .empty }),
        ]
        await performTask()
        await performTask()
        XCTAssertEqual(transitions, [
            .loading(isHidden: false),
            .loaded(.one, nil, isUpdating: false),
            .empty(nil),
        ])
    }
    
    func testLoadedUpdating() async throws {
        await setUp(
            controller: LoadingController(
                loadingBehavior: .init(delay: 0.1, minimumDuration: 0.1)
            )
        )
        tasks = [
            ScheduledTask(delay: 0.05, task: Task { .one }),
            ScheduledTask(delay: 0.15, task: Task { .two }),
        ]
        await performTask()
        await performTask()
        try await arbitraryWait()
        XCTAssertEqual(transitions, [
            .loading(isHidden: true),
            .loaded(.one, nil, isUpdating: false),
            .loaded(.one, nil, isUpdating: true),
            .loaded(.two, nil, isUpdating: false),
        ])
    }
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        controller = nil
        cancellables = Set<AnyCancellable>()
        transitions = []
        tasks = []
        taskProducer = {
            let scheduledTask = self.tasks.removeFirst()
            return Task {
                do {
                    try await Task.sleep(for: .seconds(scheduledTask.delay))
                    try Task.checkCancellation()
                    let value = try await scheduledTask.task.value
                    return value
                } catch {
                    throw error
                }
            }
        }
    }
    
    @MainActor
    private func setUp(controller: ControllerType) {
        self.controller = controller
        controller.state
            .dropFirst()
            .assignWeak(to: \.state, on: self)
            .store(in: &cancellables)
        resultSubject = PassthroughSubject<ResultType, Never>()
        resultSubject.receive(subscriber: controller.resultSubscriber)
    }
    
    @MainActor
    private var state: ControllerType.State = .loading(isHidden: true) {
        didSet {
            transitions.append(state)
        }
    }
    
    // MARK: - Helpers
    
    private func performTask() async {
        await controller.loading()
        let result = await taskProducer().result
        await controller.set(result: result)
    }
    
    /// Waits for a somewhat arbitrary amount of time, giving the publisher a beat to update the state properly.
    /// If tests unexpectedly fail, first try bumping this value up a bit.
    private func arbitraryWait() async throws {
        try await Task.sleep(for: .seconds(0.1))
    }
}
