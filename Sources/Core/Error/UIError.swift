//
//  Created by Timothy Moose on 6/18/23.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI

public struct UIError: Error, Equatable {
    
    // MARK: - API

    public var id: UUID
    public var title: String?
    public var message: String
    public var image: Image?
    public var imageColor: Color?
    public var isRetryable: Bool

    public init(
        id: UUID = UUID(),
        message: String,
        title: String?,
        image: Image?,
        imageColor: Color? = nil,
        isRetryable: Bool
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.image = image
        self.imageColor = imageColor
        self.isRetryable = isRetryable
    }

    // MARK: - Constants

    // MARK: - Variables
}
