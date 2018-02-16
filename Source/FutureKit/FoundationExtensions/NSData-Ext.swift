//
//  NSData-Ext.swift
//  FutureKit
//
//  Created by Michael Gray on 4/21/15.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation


/**
FutureKit extension for NSData.  Including class functions replacements for the thread-blocking NSData(contentsOfFile::) and NSData(contentsOfURL::)

*/
extension Data {
    
    /**
    FutureKit extension for NSData.
    
    uses executor to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    - returns: an Future<NSData>
    */
    static func data(_ executor : Executor, contentsOfFile path: String, options readOptionsMask: NSData.ReadingOptions) -> Future<Data> {
        
        return executor.execute { () -> Data in
            return try Data(contentsOf: URL(fileURLWithPath: path), options: readOptionsMask)
        }
    }
    /**
    FutureKit extension for NSData
    
    uses `Executor.Async` to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    - returns: an Future<NSData>
    */
    static func data(contentsOfFile path: String, options readOptionsMask: NSData.ReadingOptions) -> Future<Data> {
        return self.data(.async, contentsOfFile: path, options: readOptionsMask)
    }

    
    
    /**
    FutureKit extension for NSData
    
    uses executor to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    example:
         let d = NSData.data(.Async,url,DataReadingUncached).onSuccess(.Main) { (data) -> Void in
                        // use my data!
                    }
    
    
    - returns: an Future<NSData>
    */
    static func data(_ executor : Executor, contentsOfURL url: URL, options readOptionsMask: NSData.ReadingOptions) -> Future<Data> {
    
        
        return executor.execute { () -> Data in
            let data = try Data(contentsOf: url, options: readOptionsMask)
            return data
        }

    }
    /**
    FutureKit extension for NSData
    
    uses `Executor.Async` to read from path.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    - returns: an Future<NSData>
    */
    static func data(contentsOfURL url: URL, options readOptionsMask: NSData.ReadingOptions) -> Future<Data> {
        return self.data(.async, contentsOfURL: url, options: readOptionsMask)
    }

    /**
    FutureKit extension for NSData
    
    uses executor to read from contentsOfURL.  The default configuration of Executor.Async is QOS_CLASS_DEFAULT.
    
    alternative use `class func data(executor : Executor, contentsOfFile path: String, options readOptionsMask: NSDataReadingOptions)`
    
    - returns: an Future<NSData>
    */
    static func data(_ executor : Executor, contentsOfURL url: URL) -> Future<Data> {
        
        let promise = Promise<Data>()
        executor.execute { () -> Void in
            
            let data = try? Data(contentsOf: url)
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
    
    - returns: an Future<NSData>.  Fails of NSData(contentsOfUrl:url) returns a nil.
    */
    static func data(contentsOfURL url: URL) -> Future<Data> {
        return self.data(.async, contentsOfURL: url)
    }


}
