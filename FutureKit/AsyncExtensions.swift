//
//  AsyncExtensions.swift
//  FutureKit iOS
//
//  Created by Michael Gray on 1/26/18.
//  Copyright © 2018 Michael Gray. All rights reserved.
//

import Foundation


public protocol AsyncExtensionsProvider {}

extension NSObject: AsyncExtensionsProvider {}

extension AsyncExtensionsProvider {
    /// A proxy which hosts reactive extensions for `self`.
    public var async: Async<Self> {
        return Async(self)
    }

    /// A proxy which hosts static reactive extensions for the type of `self`.
    public static var async: Async<Self>.Type {
        return Async<Self>.self
    }

}

public protocol BaseAsync {
    var executor: Executor { get }
}

/// A proxy which hosts async extensions of `Base`.
public struct Async<Base> : BaseAsync {
    /// The `Base` instance the extensions would be invoked with.
    public let base: Base
    /// Construct a proxy
    ///
    /// - parameters:
    ///   - base: The object to be proxied.
    public init(_ base: Base) {
        self.base = base
    }
}

extension Async {
    public var executor: Executor {
        return .primary
    }
}


