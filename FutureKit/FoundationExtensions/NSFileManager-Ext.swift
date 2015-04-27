//
//  NSFileManager-Ext.swift
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