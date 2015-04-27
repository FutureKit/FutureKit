//: Playground - noun: a place where people can play


import Foundation

var str = "Hello, playground"


enum TestEnum {
    case HasPayload(Any)
    case Doesnt
}


let t: TestEnum = .HasPayload("hi")
let optionalI = Optional<Int>(5)
let optionalIType = Optional<Int>.self


let x = reflect(t)
let oreflect = reflect(optionalI)
let www = oreflect.valueType



let isOptional = (oreflect.disposition == .Optional)

let c = oreflect.count
let optionalType = oreflect[0].1.valueType


let what = oreflect[0]

let one = what.0
let two : MirrorType = what.1

let twoType = what.1.valueType


func typestring(x : Any) -> String
{
    if let obj = x as? NSObject {
        return NSStringFromClass((x as! NSObject).dynamicType)
    }
    
    // Native Swift
    switch x {
    case let test as Double: return "Double"
    case let test as Int: return "Int"
    case let test as Bool: return "Bool"
    case let test as String: return "String"
    default: break
    }
    
    switch x {
    case let test as [Double]: return "[Double]"
    case let test as [Int]: return "[Int]"
    case let test as [Bool]: return "[Bool]"
    case let test as [String]: return "[String]"
    default: break
    }
    
    return "<Unknown>"
}

func dispositionString(disposition : MirrorDisposition) -> String
{
    switch disposition {
    case .Aggregate: return "Aggregate"
    case .Class: return "Class"
    case .Container: return "Container"
    case .Enum: return "Enum"
    case .IndexContainer : return "Index Container (Array)"
    case .KeyContainer : return "Key Container (Dict)"
    case .MembershipContainer : return "Membership Container"
    case .ObjCObject : return "ObjC Object"
    case .Optional : return "Optional"
    case .Struct: return "Struct"
    case .Tuple: return "Tuple"
    }
}

func tupleDisposition(mirror : MirrorType) -> String
{
    if (mirror.disposition != .Tuple) {return ""}
    var array = [String]()
    for reference in 0..<mirror.count {
        let (name, referenceMirror) = mirror[reference]
        array += [typestring(referenceMirror.value)]
    }
    return array.reduce(""){"\($0),\($1)"}
}

func explore(mirror : MirrorType, _ indent:Int = 0)
{
    // dump(mirror.value) // useful
    
    let indentString = String(count: indent, repeatedValue: " " as Character)
    var ts = typestring(mirror.value)
    if (mirror.disposition == .Tuple) {
        ts = tupleDisposition(mirror)
    }
    println("\(indentString)Disposition: \(dispositionString(mirror.disposition)) [\(ts)]")
    println("\(indentString)Identifier: \(mirror.objectIdentifier)")
    println("\(indentString)ValueType: \(mirror.valueType)")
    println("\(indentString)Value: \(mirror.value)")
    println("\(indentString)Summary: \(mirror.summary)")
    
    for reference in 0..<mirror.count {
        let (name, subreference) = mirror[reference]
        println("\(indentString)Element Name: \(name)")
        explore(subreference, indent + 4)
    }
}

func generic<T : Reflectable>(value : T) {
    let o = reflect(T.self)
    explore(o, 4)

    let mm = value.getMirror()
//    let o = reflect(x)
    explore(mm, 5)

    let ot = reflect(value)
    explore(ot, 6)
    
//    let isOpt = o is Optional<Int>.self
    
    

}

let xxx : Int = 5
//generic(xxx)

generic(optionalI)


