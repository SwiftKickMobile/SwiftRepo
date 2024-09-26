//
//  Created by Ahmed Nour on 20/01/2022.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

public struct Edge<T: Decodable>: Decodable {
    ///  A cursor to the next element
    public let cursor: String?
    public let node: T

    public init(cursor: String?, node: T) {
        self.cursor = cursor
        self.node = node
    }
}

extension Edge: Equatable where T: Equatable {}
