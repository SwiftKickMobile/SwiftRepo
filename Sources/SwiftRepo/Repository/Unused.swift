//
//  Created by Mohamed Ali on 4/08/10.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A type that can be used as a generic parameter when the generic parameter is irrelevent.
/// 
/// This is very similar to the
/// `Never` type in Combine. For example, the `DefaultQueryRepository` type has three generic types `QueryId`, `Variables` and `Value`.
/// The query ID allows the repository to manage multiple separate queries to the same endpoint. If there is only one distinct query, the `Unused` type
/// can be specified for the `QueryId` parameter instead of using some other arbitrary constant, e.g. `DefaultQueryRepository<Unused, SomeVariables, SomeValue>`.
public enum Unused: Hashable, Codable {
    case unused
}
