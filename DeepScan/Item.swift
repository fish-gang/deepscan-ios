//
//  Item.swift
//  DeepScan
//
//  Created by Jason Nguyen on 08.03.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
