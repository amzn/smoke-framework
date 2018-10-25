//
//  ExampleInput.swift
//  
//
//  Created by Alex Liu on 2018-10-24.
//

import Foundation
import SmokeOperations

struct ExampleInput: Codable, Validatable {
    let theID: String
    
    func validate() throws {
        if theID.count != 12 {
            throw SmokeOperationsError.validationError(reason: "ID not the correct length.")
        }
    }
}

extension ExampleInput : Equatable {
    static func ==(lhs: ExampleInput, rhs: ExampleInput) -> Bool {
        return lhs.theID == rhs.theID
    }
}
