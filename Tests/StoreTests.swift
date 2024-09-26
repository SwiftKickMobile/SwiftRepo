//
//  Created by Timothy Moose on 6/9/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
@testable import SwiftRepo

class StoreTests: XCTestCase {
    func testDictionaryStore() async {
        await assert(store: DictionaryStore<String, String>())
    }

    func testNSCacheStore() async {
        await assert(store: NSCacheStore<String, String>())
    }

    private func assert<Store: SwiftRepo.Store>(store: Store) async where Store.Key == String, Store.Value == String {
        let key1 = "key1"
        let value1 = "value1"
        let key2 = "key2"
        let value2 = "value2"
        do {
            await store.set(key: key1, value: value1)
            await store.set(key: key2, value: value2)
            let storedValue1 = await store.get(key: key1)
            let storedValue2 = await store.get(key: key2)
            XCTAssertEqual(storedValue1, value1)
            XCTAssertEqual(storedValue2, value2)
            let age1 = await store.age(of: key1) ?? 0
            XCTAssertGreaterThan(age1, 0)
        }
        do {
            await store.set(key: key1, value: nil)
            await store.set(key: key2, value: value2)
            let storedValue1 = await store.get(key: key1)
            let storedValue2 = await store.get(key: key2)
            XCTAssertEqual(storedValue1, nil)
            XCTAssertEqual(storedValue2, value2)
            let age1 = await store.age(of: key1)
            XCTAssertNil(age1)
        }
        do {
            await store.clear()
            let storedValue1 = await store.get(key: key1)
            let storedValue2 = await store.get(key: key2)
            XCTAssertEqual(storedValue1, nil)
            XCTAssertEqual(storedValue2, nil)
        }
    }
}
