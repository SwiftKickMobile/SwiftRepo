//
//  BasicContentViewModel.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import Combine
import SwiftRepo
import Core
import Repo
import API

@MainActor
class BasicContentViewModel: ObservableObject, Refreshable {

    // MARK: - API

    @Published var loadingState: LoadingController<BasicModel>.State = .initial
    @Published var error: DemoUIError?

    init(config: BasicRepoConfig) {
        self.config = config
        repo = Repo.Dependencies.basicRepo(config: config)
        loadingController = LoadingController<BasicModel>(loadingBehavior: config.loadingBehavior)
        install()
    }

    func appeared() async {
        await load(strategy: nil)
    }

    // MARK: - Constants

    // MARK: - Variables

    private let config: BasicRepoConfig
    private let repo: any BasicRepo
    private let loadingController: LoadingController<BasicModel>

    // MARK: - Configuration

    private func install() {
        // Connect repo to loading controller
        repo.publisher()
            .receive(subscriber: loadingController.resultSubscriber)

        // Publish loading state to view
        loadingController.state
            .assign(to: &$loadingState)

        // Handle loaded errors
        loadingController.state
            .compactMap { $0.loadedIndispensableUIError as? DemoUIError}
            .assign(to: &$error)
    }

    // MARK: - Refreshable

    func refresh(retryError: DemoUIError?) async {
        let strategy: QueryStrategy = retryError == nil ? config.strategy : .always
        await load(strategy: strategy)
    }

    // MARK: - Helpers

    func load(strategy: QueryStrategy?) async {
        await repo.get(errorIntent: .indispensable, queryStrategy: strategy, willGet: loadingController.loading)
    }
}
