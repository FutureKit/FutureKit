#!/usr/bin/env xcrun swift

/*  convertPerfToCsv
   FutureKit

   Created by Michael Gray on 6/21/15.
   Copyright © 2015 Michael Gray. All rights reserved. */

import Foundation

let fname = Process.arguments[1] as String



// let bundle = NSBundle.mainBundle()

// let myFileUrl = bundle.URLForResource(fname2, withExtension: "plist")

// print(myFileUrl)

func readfile(fname : String)  {
    
    let url = NSURL(fileURLWithPath: fname)


    if let data = NSData(contentsOfURL: url) {

        let options = NSPropertyListReadOptions(rawValue: 0)


        let fileData = try! NSPropertyListSerialization.propertyListWithData(data, options: options, format: nil) as! [NSObject:[NSObject:[NSObject:[NSObject:[NSObject:AnyObject]]]]]

        let testReports = fileData["classNames"]!["LockPerformanceTests"]!

        let charset = NSCharacterSet(charactersInString: "_()")

        let allTests = testReports.keys

        for testFunctionName in allTests.array {

            let test_attributes = (testFunctionName as! NSString).componentsSeparatedByCharactersInSet(charset)

            let avg = testReports[testFunctionName]!["com.apple.XCTPerformanceMetric_WallClockTime"]!["baselineAverage"]! as! Float

            let type = test_attributes[1]
            let thread_count = test_attributes[3]
            let threadOrQueue = test_attributes[4]
            let asyncOrSyncWrite = test_attributes[5]
            let writePercentage = Float(test_attributes[7])!
            let locks = test_attributes[9]
            let contention = Float(test_attributes[11])!


            print("Type,\(type),thread_count,\(thread_count),threadOrQueue,\(threadOrQueue),asyncOrSyncWrite,\(asyncOrSyncWrite),writePercentage,\(writePercentage),locks,\(locks),contention,\(contention),avg,\(avg)")
//        print("\(test_attributes) : \(avg)")
        }
    }
    else {
        print("can't read file from \(url)")
    }

}


readfile(fname)


