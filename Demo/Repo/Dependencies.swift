//
//  Dependencies.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo
import Core
import API

public enum Dependencies {

    public static func basicRepo(config: BasicRepoConfig) -> any BasicRepo {
        let delayedValues = DelayedValues(values: config.responses)
        let store = DictionaryStore<Unused, BasicModel>()
        return DefaultConstantQueryRepository(
            variables: .unused,
            observableStore: DefaultObservableStore(store: store),
            queryStrategy: config.strategy
        ) { _ in
            // Simulate server API call via `DelayedValues`
            try await delayedValues.next()
        }
    }
}
