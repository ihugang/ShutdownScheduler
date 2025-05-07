//
//  Item.swift
//  ShutdownScheduler
//
//  Created by Hu Gang on 2025/5/7.
//

import Foundation
import SwiftData

enum ActionType: String, Codable {
    case shutdown = "关机"
    case sleep = "休眠"
}

@Model
final class Item {
    var timestamp: Date       // 执行时间
    var createdAt: Date       // 创建时间
    var scheduledTime: Date   // 计划时间
    var actionType: ActionType
    var minutes: Int          // 设置的分钟数
    
    init(timestamp: Date = Date(), actionType: ActionType, minutes: Int, scheduledTime: Date) {
        self.timestamp = timestamp
        self.createdAt = Date()
        self.actionType = actionType
        self.minutes = minutes
        self.scheduledTime = scheduledTime
    }
}
