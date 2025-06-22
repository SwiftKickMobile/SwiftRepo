//
//  Created by Timothy Moose on 8/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Testing
import Foundation
import SwiftRepoCore
@testable import SwiftRepo

@MainActor
struct DictionaryStoreTests {
    
    @Test("Set and Get value")
    func setGet() async throws {
        let store = makeStore()
        let key = "key"
        let value = TestValue(value: "value")
        _ = store.set(key: key, value: value)
        let result = store.get(key: key)
        #expect(result == value)
    }

    @Test("Set and Get nil value")
    func setGetNil() async throws {
        let store = makeStore()
        let key = "key"
        let value = TestValue(value: "value")
        _ = store.set(key: key, value: value)
        _ = store.set(key: key, value: nil)
        let result = store.get(key: key)
        #expect(result == nil)
    }

    @Test("Set with merge operation")
    func setMerge() async throws {
        let store = makeStore()
        let key = "key"
        let value1 = TestValue(value: "value1")
        let value2 = TestValue(value: "value2")
        _ = store.set(key: key, value: value1)
        _ = store.set(key: key, value: value2)
        let result = store.get(key: key)
        #expect(result == TestValue(value: "value1value2"))
    }

    // MARK: - Constants

    private struct TestValue: Codable, Equatable, Sendable {
        let value: String
    }

    // MARK: - Helpers

    private func makeStore() -> DictionaryStore<String, TestValue> {
        DictionaryStore { old, new in TestValue(value: old.value + new.value) }
    }
}
