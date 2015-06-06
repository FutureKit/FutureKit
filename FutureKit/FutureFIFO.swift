//
//  FutureFIFO.swift
//  FutureKit
//
//  Created by Michael Gray on 5/4/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation


// can execute a FIFO set of Blocks and Futures, guaranteeing that Blocks and Futures execute in order
public class FutureFIFO {
    
    private var lastFuture = Future<Void>(success: ())
    
    
    // add a block and it won't execute until all previosuly submitted Blocks have finished and returned a result.
    // If the block returns a result, than the next ask in the queue is started.
    // If the block returns a Task, that Task must complete before the next block in the Queue is executed.
    
    // A Failed or Canceled task doesn't stop execution of the queue
    // If you care about the Result of specific committed block, you can add a dependency to the Task returned from this function
    public final func addBlock<__Type>(executor: Executor, _ block: () -> __Type) -> Future<__Type> {
        
        let t = self.lastFuture.onComplete (executor) { (completion) -> __Type in
            return block()
        }
        self.lastFuture = t.As()
        return t
    }

    public final func addBlock<__Type>(block: () -> __Type) -> Future<__Type> {
        
        return self.addBlock(.Primary,block)
    }

    public final func addBlock<__Type>(executor: Executor, _ block: () -> Future<__Type>) -> Future<__Type> {
    
        let t = self.lastFuture.onComplete { (completion) -> Future<__Type> in
            return block()
        }
        self.lastFuture = t.As()
        return t
    }

    public final func addBlock<__Type>(block: () -> Future<__Type>) -> Future<__Type> {
        
        return self.addBlock(.Primary,block)
    }
    

}
