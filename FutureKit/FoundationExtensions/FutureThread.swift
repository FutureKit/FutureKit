//
//  FKThread.swift
//  FutureKit
//
//  Created by Michael Gray on 6/19/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

extension Async where Base: Thread {
    @available(iOS 10.0, *)
    static func futureThread<T>(_ block: @escaping () throws -> T) -> Future<T> {
        let p = Promise<T>()
        Thread.detachNewThread { 
            p.completeWithBlock { () -> Completion<T> in
                return .success(try block())
            }
        }
        return p.future
    }
    @available(iOS 10.0, *)
    static func futureThread<C: CompletionConvertable>(_ block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        Thread.detachNewThread { 
            p.completeWithBlock { () -> Completion<C.T> in
                return try block().completion
            }
        }
        return p.future
    }
    
}

public class FutureThread<T>: Foundation.Thread {
    
    private var promise = Promise<T>()
    
    public var future: Future<T> {
        return promise.future
    }
    private var block: () throws -> Completion<T>
    
    public init<C: CompletionConvertable>(_ transform: @escaping () throws -> C) where C.T == T {
        
        self.block = { 
            return try transform().completion
        }
        super.init()
    }

    public init(_ transform: @escaping () throws -> T) {
        
        self.block = { 
            return .success(try transform())
        }
        super.init()
    }
    override public func main() {
        self.run()
    }
    
    private func run() {
        self.promise.completeWithBlock { () throws -> Completion<T> in
            try self.block()
        }        
    }
    
}
