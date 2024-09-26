//
//  Created by Timothy Moose on 10/29/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

public struct PageInfo: Decodable, Equatable {
    // MARK: - API

    public let cursor: String?
    public let pageSize: Int
    public let hasNext: Bool
    public let nextCursor: String?
    public let totalNodes: Int

    public init(
        cursor: String?,
        pageSize: Int,
        hasNext: Bool,
        nextCursor: String?,
        totalNodes: Int
    ) {
        self.cursor = cursor
        self.pageSize = pageSize
        self.hasNext = hasNext
        self.nextCursor = nextCursor
        self.totalNodes = totalNodes
    }
}
