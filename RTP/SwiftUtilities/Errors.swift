//
//  Errors.swift
//  SwiftUtilities
//
//  Created by Jonathan Wight on 6/27/15.
//
//  Copyright (c) 2014, Jonathan Wight
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


import Foundation

public protocol ErrorType {
}

extension NSError: ErrorType {
}

// TODO: This is kinda crap.
public enum Error: ErrorType {
    case none
    case generic(String)
    case dispatchIO(Int32, String)
    case posix(Int32, String)
    case todo
}

typealias CustomStringConvertible = Printable

extension Error: CustomStringConvertible {
    public var description: String {
        switch self {
            case .none:
                return "None"
            case .generic(let string):
                return string
            case .dispatchIO(let code, let string):
                return "\(code) \(string)"
            case .posix(let code, let string):
                return "\(code) \(string)"
            case .todo:
                return "todo"
        }
    }
}

public func makeOSStatusError <T: IntegerType>(status: T, description: String? = nil) -> ErrorType {

    var userInfo: [NSObject: AnyObject]? = nil

    if let description = description {
        userInfo = [NSLocalizedDescriptionKey: description]
    }


    let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status.toIntMax()), userInfo: userInfo)
    return error
}


@noreturn public func unimplementedFailure(@autoclosure message: () -> String = "", file: StaticString = __FILE__, line: UInt = __LINE__) {
    preconditionFailure(message, file: file, line: line)
}

