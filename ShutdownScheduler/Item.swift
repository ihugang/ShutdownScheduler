//
//  Item.swift
//  ShutdownScheduler
//
//  Created by Hu Gang on 2025/5/7.
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
