//
//  FileLineInfo.swift
//  FutureKit
//
//  Created by Michael Gray on 2/2/18.
//  Copyright © 2018 Michael Gray. All rights reserved.
//

import Foundation


extension StaticString {

    public var string: String {
        return self.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}

public enum FileLineInfo: CustomStringConvertible, CustomDebugStringConvertible {
    case fileLine(StaticString, UInt)
    case fileFunctionLine(StaticString, StaticString, UInt)
    case stackedFileLine(StaticString, UInt, StaticString, UInt)
    case unknownLocation

    public init(_ file: StaticString, _ line: UInt) {
        self = .fileLine(file, line)
    }

    public init(_ file: StaticString, _ line: UInt, previous: FileLineInfo) {
        self = .stackedFileLine(file, line, previous.file, previous.line)
    }

    public init(_ current: FileLineInfo, previous: FileLineInfo) {
        assert({
            switch current {
            case .stackedFileLine:
                return false
            default:
                return true
            }
        }(), "you can't stack a stacked FileLineInfo with a stacked FileLineInfo!")
        self = .stackedFileLine(current.file, current.line,  previous.file, previous.line)
    }

    public init(_ tuple: (StaticString, UInt)) {
        self = .fileLine(tuple.0, tuple.1)
    }

    public static func anchorFromHere(_ file: StaticString = #file,
                                      _ line: UInt = #line) -> FileLineInfo {
        return FileLineInfo(file, line)
    }


    public var function: StaticString {
        switch self {
        case let .fileFunctionLine(_, function, _):
            return function
        default:
            return "???"
        }
    }

    public var file: StaticString {
        switch self {
        case let .fileLine(file, _):
            return file
        case let .fileFunctionLine(file, _, _):
            return file
        case let .stackedFileLine(file, _, _, _):
            return file
        case .unknownLocation:
            return "???"
        }
    }
    public var line: UInt {
        switch self {
        case let .fileLine(_, line):
            return line
        case let .fileFunctionLine(_, _, line):
            return line
        case let .stackedFileLine(_, line, _ , _):
            return line
        case .unknownLocation:
            return UInt.max
        }
    }

    public var shortFileName: String {
        switch self {
        case .unknownLocation:
            return "???"
        default:
            return URL(fileURLWithPath: file.string).lastPathComponent
        }
    }

//    public var next: FileLineInfo? {
//        switch self {
//        case let .stackedFileLine(_, second):
//            return second
//        default:
//            return nil
//        }
//    }
//
//    public func reduce<U>(_ initialResult: U, _ nextPartialResult: (U, FileLineInfo) -> U) -> U {
//        var value = nextPartialResult(initialResult, self)
//        var next = self.next
//        while next != nil {
//            let fileLineInfo = next!
//            value = nextPartialResult(initialResult, fileLineInfo)
//            next = fileLineInfo.next
//        }
//        return value
//    }
//
//    public var size: Int {
//        return self.reduce(0) { sum,_ in sum + 1 }
//    }

    public var shortDescription: String {
        switch self {
        case let .fileLine(_, line):
            return "[\(shortFileName):\(line)]"
        case let .stackedFileLine(_, line, _, _):
            return "[\(shortFileName):\(line)]"
        case let .fileFunctionLine(_, function, line):
            return "[\(shortFileName):\(function)\(line)]"
        case .unknownLocation:
            return "[???:???]"
        }
    }


    public var description: String {
//        switch self {
//        case .stackedFileLine:
//            return self.reduce("StackedFile:\n") { "\($0)\($1.shortDescription)\n"}
//        default:
            return "File:[\(shortDescription)]"
//        }
    }

    public var debugDescription: String {
        return self.description
    }
}
