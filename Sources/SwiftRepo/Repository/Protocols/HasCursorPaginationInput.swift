//
//  Created by Timothy Moose on 11/7/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// Adopted by server response types that include cursore-based paging.
public protocol HasCursorPaginationInput {
    var cursorPage: CursorPaginationInput? { get }

    /// Returns an identical input, but representing the given cursor.
    func with(cursor: String?) -> Self
}

public extension HasCursorPaginationInput {
    /// Returns an identical input, but representing the first page.
    var asFirstPage: Self {
        with(cursor: nil)
    }

    /// `true` if the data does not represent the first page.
    var isPaging: Bool {
        cursorPage?.cursor != nil
    }
}
