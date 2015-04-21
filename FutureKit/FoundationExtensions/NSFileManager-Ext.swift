//
//  NSFileManager-Ext.swift
//  FutureKit
//
//  Created by Michael Gray on 4/21/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation


private var executorVarHandler = ExtensionVarHandlerFor<NSFileManager>()

/** adds an Extension that automatically routes requests to Executor.Default (or some other configured Executor)

*/
extension NSFileManager {

    // is this a good idea?  
    // Should I make two versions of the all the APIs? One with and one without?

/*    private var executor : Executor {
        get {
            return executorVarHandler.getValueFrom(self,defaultvalue: Executor.Default)
        }
        set(newValue) {
            executorVarHandler.setValueOn(self, value: newValue)
        }
    } */

    func copyItemAtURL(executor : Executor, srcURL: NSURL, toURL dstURL: NSURL) -> Future<Bool>
    {
        let p = Promise<Bool>()
        
        executor.execute { () -> Void in
            var error : NSError?
            
            let ret = self.copyItemAtURL(srcURL, toURL: dstURL, error: &error)
            if (error != nil) {
                p.completeWithFail(error!)
            }
            else {
                p.completeWithSuccess(ret)
            }
        }
        return p.future
    }
    
    func moveItemAtURL(executor : Executor, srcURL: NSURL, toURL dstURL: NSURL) -> Future<Bool>
    {
        let p = Promise<Bool>()
        
        executor.execute { () -> Void in
            var error : NSError?
            
            let ret = self.moveItemAtURL(srcURL, toURL: dstURL, error: &error)
            if (error != nil) {
                p.completeWithFail(error!)
            }
            else {
                p.completeWithSuccess(ret)
            }
        }
        return p.future
    }
    func linkItemAtURL(executor : Executor, srcURL: NSURL, toURL dstURL: NSURL) -> Future<Bool>
    {
        let p = Promise<Bool>()
        
        executor.execute { () -> Void in
            var error : NSError?
            
            let ret = self.linkItemAtURL(srcURL, toURL: dstURL, error: &error)
            if (error != nil) {
                p.completeWithFail(error!)
            }
            else {
                p.completeWithSuccess(ret)
            }
        }
        return p.future
    }
    
    func removeItemAtURL(executor : Executor,URL: NSURL) -> Future<Bool>
    {
        let p = Promise<Bool>()
        
        executor.execute { () -> Void in
            var error : NSError?
            
            let ret = self.removeItemAtURL(URL, error: &error)
            if (error != nil) {
                p.completeWithFail(error!)
            }
            else {
                p.completeWithSuccess(ret)
            }
        }
        return p.future
    }

    // Needs more love!  If you are reading this and you wanted to see your favorite function added - consider forking and adding it!  We love pull requests.
    

}