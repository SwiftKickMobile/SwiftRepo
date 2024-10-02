//
//  ErrorView.swift
//  UI
//
//  Created by Carter Foughty on 8/5/24.
//

import SwiftUI
import SwiftRepoCore

public struct ErrorView: View {
    
    // MARK: - API
    
    public init(error: any UIError) {
        self.error = error
    }
    
    // MARK: - Constants
    
    // MARK: - Variables
    
    private let error: any UIError
    
    // MARK: - Body
    
    public var body: some View {
        Text("Error")
    }

    // MARK: - Helpers
    
}

#Preview {
    ErrorView(error: DefaultUIError.default(isRetryable: false))
}
