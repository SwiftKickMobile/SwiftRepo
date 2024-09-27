//
//  Created by Timothy Moose on 12/14/23.
//

import Foundation

public protocol AppError: Error {
    associatedtype UIErrorType = any UIError
    
    /// Optional error data to present to the user
    var uiError: UIErrorType? { get }

    /// `true` if error should be logged
    var isNotable: Bool { get }
    
    /// `true` if action that led to error can be retried
    var isRetryable: Bool { get }
    
    /// Indicates an intent or purpose for the error from the perspective of the caller
    /// This may be useful for indicating whether an error is intended to be displayed.
    var intent: ErrorIntent { get set }
}
