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

public enum FileLineInfo: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case fileLine(StaticString, UInt)
    case fileFunctionLine(StaticString, StaticString, UInt)
    case unknownLocation

    public init(_ file: StaticString, _ line: UInt) {
        self = .fileLine(file, line)
    }

    public init(_ tuple: (StaticString, UInt)) {
        self = .fileLine(tuple.0, tuple.1)
    }

    public static func anchorFromHere(_ file: StaticString = #file,
                                      _ line: UInt = #line) -> FileLineInfo {
        return FileLineInfo(file, line)
    }

    // swiftlint:disable:next cyclomatic_complexity
    public static func == (lhs: FileLineInfo, rhs: FileLineInfo) -> Bool {
        switch lhs {
        case let .fileLine(lhsFile, lhsLine):
            switch rhs {
            case let .fileLine(rhsFile, rhsLine):
                return lhsLine == rhsLine && lhsFile.string == rhsFile.string
            case let .fileFunctionLine(rhsFile, _, rhsLine):
                return lhsLine == rhsLine && lhsFile.string == rhsFile.string
            case .unknownLocation:
                return false
            }
        case let .fileFunctionLine(lhsFile, _, lhsLine):
            switch rhs {
            case let .fileLine(rhsFile, rhsLine):
                return lhsLine == rhsLine && lhsFile.string == rhsFile.string
            case let .fileFunctionLine(rhsFile, _, rhsLine):
                return lhsLine == rhsLine && lhsFile.string == rhsFile.string
            case .unknownLocation:
                return false
            }
        case .unknownLocation:
            switch rhs {
            case .fileLine:
                return false
            case .fileFunctionLine:
                return false
            case .unknownLocation:
                return true
            }
        }
    }


    public var function: StaticString {
        switch self {
        case .fileLine:
            return "???"
        case let .fileFunctionLine(_, function, _):
            return function
        case .unknownLocation:
            return "???"
        }
    }

    public var file: StaticString {
        switch self {
        case let .fileLine(file, _):
            return file
        case let .fileFunctionLine(file, _, _):
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
        case .unknownLocation:
            return UInt.max
        }
    }

    public var shortFileName: String {
        switch self {
        case let .fileLine(file, _):
            return URL(fileURLWithPath: file.string).lastPathComponent
        case let .fileFunctionLine(file, _, _):
            return URL(fileURLWithPath: file.string).lastPathComponent
        case .unknownLocation:
            return "???"
        }
    }
    public var description: String {
        switch self {
        case let .fileLine(_, line):
            return "File:[\(shortFileName):\(line)]"
        case let .fileFunctionLine(_, function, line):
            return "File:[\(shortFileName):\(function)\(line)]"
        case .unknownLocation:
            return "File:[???:???]"
        }
    }

    public var debugDescription: String {
        return self.description
    }
}
