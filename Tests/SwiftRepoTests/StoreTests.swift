//
//  Created by Timothy Moose on 6/9/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Testing
@testable import SwiftRepo

@MainActor
struct StoreTests {
    
    @Test("DictionaryStore basic operations")
    func dictionaryStore() async throws {
        try await assert(store: DictionaryStore<String, String>())
    }

    @Test("NSCacheStore basic operations")
    func nsCacheStore() async throws {
        try await assert(store: NSCacheStore<String, String>())
    }

    private func assert<Store: SwiftRepo.Store>(store: Store) async throws where Store.Key == String, Store.Value == String {
        let key1 = "key1"
        let value1 = "value1"
        let key2 = "key2"
        let value2 = "value2"
        
        // Test setting and getting values
        try await store.set(key: key1, value: value1)
        try await store.set(key: key2, value: value2)
        let storedValue1 = try await store.get(key: key1)
        let storedValue2 = try await store.get(key: key2)
        #expect(storedValue1 == value1)
        #expect(storedValue2 == value2)
        let age1 = try await store.age(of: key1) ?? 0
        #expect(age1 > 0)
        
        // Test setting nil values
        try await store.set(key: key1, value: nil)
        try await store.set(key: key2, value: value2)
        let storedValue1After = try await store.get(key: key1)
        let storedValue2After = try await store.get(key: key2)
        #expect(storedValue1After == nil)
        #expect(storedValue2After == value2)
        let age1After = try await store.age(of: key1)
        #expect(age1After == nil)
        
        // Test clearing store
        try await store.clear()
        let storedValue1Final = try await store.get(key: key1)
        let storedValue2Final = try await store.get(key: key2)
        #expect(storedValue1Final == nil)
        #expect(storedValue2Final == nil)
    }
}
