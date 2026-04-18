//
//  Item.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
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
