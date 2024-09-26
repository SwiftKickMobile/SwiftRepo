//
//  Created by Timothy Moose on 8/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
@testable import SwiftRepo

class DictionaryStoreTests: XCTestCase {
    // MARK: - Tests

    func test_mergingOperator_sumsValues() async {
        let key = "key"
        let store = makeStore()
        do {
            _ = await store.set(key: key, value: TestValue(value: 1))
            let stored = await store.get(key: key)
            XCTAssertEqual(stored?.value, 1)
        }
        do {
            _ = await store.set(key: key, value: TestValue(value: 2))
            let stored = await store.get(key: key)
            XCTAssertEqual(stored?.value, 3)
        }
        do {
            _ = await store.set(key: key, value: nil)
            let stored = await store.get(key: key)
            XCTAssertNil(stored)
        }
    }

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Lifecycle

    // MARK: - Helpers

    private func makeStore() -> DictionaryStore<String, TestValue> {
        DictionaryStore { old, new in TestValue(value: old.value + new.value) }
    }
}

private struct TestValue {
    var value: Int
}
