//
//  NSData-Ext.swift
//  FutureKit
//
//  Created by Michael Gray on 4/21/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation


/**
FutureKit extension for NSData.  Including class functions replacements for the thread-blocking NSData(contentsOfFile::) and NSData(contentsOfURL::)

*/
extension NSData {
    
    /**
    FutureKit extension for NSData.
    
    uses executor to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    :returns: an Future<NSData>
    */
    class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions) -> Future<NSData> {
        
        let promise = Promise<NSData>()
        executor.execute { () -> Void in
            var error : NSError?
            let data = NSData(contentsOfFile: path, options: readOptionsMask, error: &error)
            if (error != nil) {
                promise.completeWithFail(error!)
            }
            else if let d = data {
                promise.completeWithSuccess(d)
            }
            else {
                promise.completeWithFail("nil returned from NSData(contentsOfFile:\(path),options:\(readOptionsMask))")
            }
        }
        return promise.future
    }
    /**
    FutureKit extension for NSData
    
    uses `Executor.Async` to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    :returns: an Future<NSData>
    */
    class func data(contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions) -> Future<NSData> {
        return self.data(.Async, contentsOfFile: path, options: readOptionsMask)
    }

    
    
    /**
    FutureKit extension for NSData
    
    uses executor to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    example:
         let d = NSData.data(.Async,url,DataReadingUncached).onSuccess(.Main) { (data) -> Void in
                        // use my data!
                    }
    
    
    :returns: an Future<NSData>
    */
    class func data(executor : Executor, contentsOfURL url: NSURL, options readOptionsMask: NSDataReadingOptions) -> Future<NSData> {
        
        let promise = Promise<NSData>()
        executor.execute { () -> Void in
            var error : NSError?
            let data = NSData(contentsOfURL: url, options: readOptionsMask, error: &error)
            if (error != nil) {
                promise.completeWithFail(error!)
            }
            else if let d = data {
                promise.completeWithSuccess(d)
            }
            else {
                promise.completeWithFail("nil returned from NSData(contentsOfURL:\(url),options:\(readOptionsMask))")
            }
        }
        return promise.future
    }
    /**
    FutureKit extension for NSData
    
    uses `Executor.Async` to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    :returns: an Future<NSData>
    */
    class func data(contentsOfURL url: NSURL, options readOptionsMask: NSDataReadingOptions) -> Future<NSData> {
        return self.data(.Async, contentsOfURL: url, options: readOptionsMask)
    }

    /**
    FutureKit extension for NSData
    
    uses executor to read from contentsOfURL.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    :returns: an Future<NSData>
    */
    class func data(executor : Executor, contentsOfURL url: NSURL) -> Future<NSData> {
        
        let promise = Promise<NSData>()
        executor.execute { () -> Void in
            var error : NSError?
            let data = NSData(contentsOfURL: url)
            if let d = data {
                promise.completeWithSuccess(d)
            }
            else {
                promise.completeWithFail("nil returned from NSData(contentsOfURL:\(url))")
            }
        }
        return promise.future
    }
    /**
    FutureKit extension for NSData
    
    uses `Executor.Async` to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    :returns: an Future<NSData>.  Fails of NSData(contentsOfUrl:url) returns a nil.
    */
    class func data(contentsOfURL url: NSURL) -> Future<NSData> {
        return self.data(.Async, contentsOfURL: url)
    }


}