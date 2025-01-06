//
//  EmptyRepo.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo
import Core
import API

public typealias BasicRepo = ConstantQueryRepository<Unused, BasicModel>

public struct BasicRepoConfig {

    public typealias LoadingBehavior = LoadingController<BasicModel>.LoadingBehavior
    public typealias Responses = [DelayedValues<BasicModel>.Value]

    public var strategy: QueryStrategy
    public var loadingBehavior: LoadingBehavior
    public var responses: Responses

    public init() {
        self.init(strategy: .always, loadingBehavior: .init(delay: 0, minimumDuration: 0), responses: [])
    }

    public init(strategy: QueryStrategy, loadingBehavior: LoadingBehavior, responses: Responses) {
        self.strategy = strategy
        self.loadingBehavior = loadingBehavior
        self.responses = responses
    }
}

extension BasicModel: @retroactive Emptyable {
    public var isEmpty: Bool {
        items.isEmpty
    }
}
