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


private var executorVarHandler = ExtensionVarHandlerFor<FileManager>()

/** adds an Extension that automatically routes requests to Executor.Default (or some other configured Executor)

*/
extension Async where Base: FileManager {
    
    public var executor: Executor {
        return .default
    }

    public func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: FileManager.VolumeEnumerationOptions = []) -> Future<[URL]?> {

        return self.executor.execute { () -> [URL]? in
            return self.base.mountedVolumeURLs(includingResourceValuesForKeys: propertyKeys,
                                               options: options)
        }
    }

    public func contentsOfDirectory(at url: URL, 
                                    includingPropertiesForKeys keys: [URLResourceKey]?, 
                                    options mask: FileManager.DirectoryEnumerationOptions = []) -> Future<[URL]> {
        
        return self.executor.execute { () -> [URL] in
            return try self.base.contentsOfDirectory(at: url,
                                                 includingPropertiesForKeys: keys,
                                                 options: mask)
        }
    }

  
    public func copyItem(at srcURL: URL, to dstURL: URL) -> Future<Bool>
    {
        return self.executor.execute { () -> Bool in
            try self.base.copyItem(at: srcURL, to: dstURL)
            return true
        }
    }
    
    public func moveItem(at srcURL: URL, to dstURL: URL) -> Future<Bool>
    {
        return self.executor.execute { () -> Bool in
            try self.base.moveItem(at: srcURL, to: dstURL)
            return true
        }

    }
    
    public func linkItem(at srcURL: URL, to dstURL: URL) -> Future<Bool>
    {
        return self.executor.execute { () -> Bool in
            try self.base.linkItem(at: srcURL, to: dstURL)
            return true
        }
    }
    
    public func removeItem(at URL: Foundation.URL) -> Future<Bool>
    {
        return self.executor.execute { () -> Bool in
            try self.base.removeItem(at: URL)
            return true
        }
    }

    // Needs more love!  If you are reading this and you wanted to see your favorite function added - consider forking and adding it!  We love pull requests.
    
}
