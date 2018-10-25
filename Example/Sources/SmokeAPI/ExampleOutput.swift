//
//  ExampleOutput.swift
//  
//
//  Created by Alex Liu on 2018-10-24.
//

import Foundation
import SmokeOperations

enum BodyColor: String, Codable {
    case yellow = "YELLOW"
    case blue = "BLUE"
}

struct ExampleOutput: Codable, Validatable {
    let bodyColor: BodyColor
    let isGreat: Bool
    
    func validate() throws {
        if case .yellow = bodyColor {
            throw SmokeOperationsError.validationError(reason: "The body color is yellow.")
        }
    }
}

extension ExampleOutput : Equatable {
    static func ==(lhs: ExampleOutput, rhs: ExampleOutput) -> Bool {
        return lhs.bodyColor == rhs.bodyColor
            && lhs.isGreat == rhs.isGreat
    }
}
