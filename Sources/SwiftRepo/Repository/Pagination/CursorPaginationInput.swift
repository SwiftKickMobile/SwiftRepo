//
//  Created by Joseph Lauletta on 8/2/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// Model representing pagination inputs for GQL queries.
public struct CursorPaginationInput: Encodable, Hashable {
    // MARK: - API

    public static let defaultPageSize = 50

    public let cursor: String?
    public let pageSize: Int

    /// - Parameters:
    ///     - cursor: Cursor position to return nodes after.
    ///     - pageSize: Maximum number of nodes to return. Defaults to `50`
    public init(cursor: String?, pageSize: Int = defaultPageSize) {
        self.cursor = cursor
        self.pageSize = pageSize
    }
}
