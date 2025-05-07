//
//  ShutdownSchedulerApp.swift
//  ShutdownScheduler
//
//  Created by Hu Gang on 2025/5/7.
//

import SwiftUI
import SwiftData

@main
struct ShutdownSchedulerApp: App {
   @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
   
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // 使用空的WindowGroup，这样应用程序启动时不会显示主窗口
        WindowGroup(id: "hidden") {
            EmptyView()
        }
        .modelContainer(sharedModelContainer)
        // 添加设置项，允许用户通过菜单访问设置
        Settings {
            Text("定时关机/休眠工具设置")
                .font(.headline)
        }
    }
}
