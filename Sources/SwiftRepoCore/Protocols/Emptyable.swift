//
//  Created by Timothy Moose on 11/19/15.
//  Copyright © 2015 SwiftKick Mobile LLC. All rights reserved.
//

import Foundation

public protocol Emptyable {
    var isEmpty: Bool { get }
}

/*
 MARK: - Extensions
 */

extension Bool: Emptyable {
    public var isEmpty: Bool { return !self }
}

extension Array: Emptyable {}

extension Set: Emptyable  {}

extension Dictionary: Emptyable {}

extension String: Emptyable {}

extension Optional: Emptyable {

    public var isEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let wrapped):
            if let emtpyableWrapped = wrapped as? Emptyable {
                return emtpyableWrapped.isEmpty
            }
            // Lets have an assertion here so we can identify other types that
            // we want to have implementing the Emptyable protocol
            assert(false)
            return false
        }
    }
}
