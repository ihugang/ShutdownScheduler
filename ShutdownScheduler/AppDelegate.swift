import Cocoa
import SwiftUI
import Combine
import Foundation
import os.log

// 创建一个自定义的NSView类来显示倒计时和图标
class StatusItemView: NSView {
    private var timeLabel: NSTextField!
    private var iconView: NSImageView!
    private var backgroundView: NSView!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // 计算垂直居中的Y坐标
        let centerY = (frame.height - 18) / 2
        
        // 创建不透明背景图层
        backgroundView = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.darkGray.cgColor
        addSubview(backgroundView)
        
        // 创建图标视图 - 将图标放在最左边
        iconView = NSImageView(frame: NSRect(x: 8, y: centerY, width: 18, height: 18))
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)
        
        // 创建时间标签
        timeLabel = NSTextField(frame: NSRect(x: 26, y: centerY, width: 50, height: 18))
        timeLabel.isEditable = false
        timeLabel.isBordered = false
        timeLabel.drawsBackground = false
        timeLabel.font = NSFont.boldSystemFont(ofSize: 12)
        timeLabel.textColor = NSColor.white  // 使用白色文字
        timeLabel.alignment = .left
        addSubview(timeLabel)
    }
    
    func update(time: String, icon: NSImage?) {
        timeLabel.stringValue = time
        iconView.image = icon
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // 基本UI组件
    var window: NSWindow?
    var popover = NSPopover()
    var statusItem: NSStatusItem? // 单一状态栏项
    
    // 视图和图标
    var statusItemView: StatusItemView?
    var originalIcon: NSImage?
    
    // 状态和计时器
    var isCountingDown = false
    var remainingSeconds = 0
    var selectedAction = ""
    var menuBarUpdateTimer: Timer?
    
    // 设置窗口
    private var settingsWindowController: SettingsWindowController?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.ShutdownScheduler", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[调试] 应用程序启动")
        // 隐藏dock图标
        NSApp.setActivationPolicy(.accessory)
        
        // 关闭所有窗口
        NSApp.windows.forEach { $0.close() }
        
        // 确保不过度激活应用
        NSApp.deactivate()
        
        // 创建 ContentView 并传入回调函数
        let contentView = ContentView(countdownStateChanged: { [weak self] isCountingDown, remainingSeconds, actionType in
            guard let self = self else { return }
            
            self.handleCountdownStateChange(isCountingDown: isCountingDown, remainingSeconds: remainingSeconds, selectedAction: actionType.rawValue)
        })
        
        // 设置弹出窗口
        popover.contentSize = NSSize(width: 350, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // 注册强制重置通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceReset),
            name: Notification.Name("ForceStatusItemReset"),
            object: nil
        )
        
        // 创建状态栏图标
        createStatusItem()
        
        // 显示主界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    @objc func handleForceReset() {
        print("[调试] 接收到强制重置通知")
        
        // 停止定时器
        stopMenuBarUpdateTimer()
        
        // 强制重置状态变量
        isCountingDown = false
        remainingSeconds = 0
        
        // 强制删除并重建状态栏
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.displayNormalStatusItem()
        }
    }
    
    // MARK: - 倒计时状态更改回调
    func handleCountdownStateChange(isCountingDown: Bool, remainingSeconds: Int, selectedAction: String) {
        print("[调试] 倒计时状态更改: isCountingDown=\(isCountingDown), remainingSeconds=\(remainingSeconds), selectedAction=\(selectedAction)")
        
        // 停止任何正在进行的定时器和延迟操作
        stopMenuBarUpdateTimer()
        
        // 设置状态变量
        self.isCountingDown = isCountingDown
        self.remainingSeconds = remainingSeconds
        self.selectedAction = selectedAction
        
        // 立即清除状态栏显示
        DispatchQueue.main.async {
            self.statusItem?.button?.subviews.forEach { $0.removeFromSuperview() }
            self.statusItemView = nil
            
            // 根据状态选择显示方式
            if isCountingDown {
                self.startMenuBarUpdateTimer()
                self.updateMenuBarDisplay() // 立即更新显示
            } else {
                self.displayNormalStatusItem() // 显示正常状态
            }
        }
    }
    
    // MARK: - 状态栏控制
    func createStatusItem() {
        // 创建一个状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 加载图标
        var icon: NSImage? = nil
        
        // 先尝试加载自定义图标
        if let bundleIcon = NSImage(named: "StatusBarIcon") {
            icon = bundleIcon
        } else if let customIcon = NSImage(named: "icon_white") {
            icon = customIcon
        } else if let systemIcon = NSImage(systemSymbolName: "timer", accessibilityDescription: "Timer") {
            icon = systemIcon
        }
        
        // 设置图标和大小
        icon?.size = NSSize(width: 18, height: 18)
        statusItem?.button?.image = icon
        originalIcon = icon
        
        // 设置点击动作 - 左键点击显示主界面
        statusItem?.button?.action = #selector(togglePopover(_:))
        
        // 添加右键菜单
        let rightClickMenu = createMenu()
        statusItem?.menu = rightClickMenu
        
        logger.info("创建状态栏图标: \(icon != nil ? "成功" : "失败")")
    }
    

    
    // 创建右键菜单
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 添加定时关机选项
        let shutdownItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "shutdown_menu", defaultValue: "定时关机"), 
                                     action: #selector(scheduleShutdown(_:)), 
                                     keyEquivalent: "s")
        shutdownItem.target = self
        menu.addItem(shutdownItem)
        
        // 添加定时休眠选项
        let sleepItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "sleep_menu", defaultValue: "定时休眠"), 
                                  action: #selector(scheduleSleep(_:)), 
                                  keyEquivalent: "l")
        sleepItem.target = self
        menu.addItem(sleepItem)
        
        // 添加取消定时选项
        let cancelItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "cancel_menu", defaultValue: "取消定时"), 
                                   action: #selector(cancelSchedule(_:)), 
                                   keyEquivalent: "c")
        cancelItem.target = self
        menu.addItem(cancelItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加设置项
        let settingsItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "settings_menu", defaultValue: "设置..."), 
                                     action: #selector(openSettings(_:)), 
                                     keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加关于项
        let aboutItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "about_menu", defaultValue: "关于"), 
                                  action: #selector(showAbout(_:)), 
                                  keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // 添加退出项
        let quitItem = NSMenuItem(title: SettingsManager.shared.localizedString(for: "quit_menu", defaultValue: "退出"), 
                                 action: #selector(NSApplication.terminate(_:)), 
                                 keyEquivalent: "q")
        menu.addItem(quitItem)
        
        return menu
    }
    
    /// 显示正常状态（非倒计时状态）
    private func displayNormalStatusItem() {
        print("[调试] 开始恢复正常状态...")
        
        // 最彻底的解决方案: 完全移除旧状态栏并创建新的
        if let oldItem = statusItem {
            NSStatusBar.system.removeStatusItem(oldItem)
        }
        
        // 创建新的状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 加载图标
        var icon: NSImage? = nil
        
        // 先尝试加载自定义图标
        if let customIcon = NSImage(named: "icon_white") {
            icon = customIcon
        } else {
            // 使用系统图标
            icon = NSImage(systemSymbolName: "power", accessibilityDescription: "Shutdown")
        }
        
        icon?.size = NSSize(width: 18, height: 18)
        originalIcon = icon
        
        // 设置状态栏图标
        statusItem?.button?.image = icon
        
        // 设置点击动作 - 左键点击显示主界面
        statusItem?.button?.action = #selector(togglePopover(_:))
        
        // 添加右键菜单
        let rightClickMenu = createMenu()
        statusItem?.menu = rightClickMenu
        
        // 清理引用
        statusItemView = nil
        
        print("[调试] 恢复正常状态显示 - 完成")
    }
    
    /// 显示倒计时状态
    private func displayCountdownView(time: String, icon: NSImage?) {
        // 当前状态是否倒计时
        if !isCountingDown {
            print("[调试] 已取消显示倒计时，当前不在倒计时状态")
            return
        }
        
        // 在全局队列中执行，确保与其他状态同步
        DispatchQueue.global().async {
            // 再次检查状态，可能已经变化
            if !self.isCountingDown {
                print("[调试] 再次取消显示倒计时，状态已改变")
                return
            }
            
            // 在主线程中更新UI
            DispatchQueue.main.async {
                // 再次最终检查
                if !self.isCountingDown {
                    print("[调试] 最终取消显示倒计时，状态已改变")
                    return
                }
                
                // 先彻底清除之前的内容
                self.statusItem?.button?.subviews.forEach { $0.removeFromSuperview() }
                self.statusItem?.button?.image = nil
                self.statusItem?.button?.title = ""
                
                // 使用黑色样式
                if let button = self.statusItem?.button {
                    button.appearance = NSAppearance(named: .darkAqua)
                }
                
                // 设置固定长度
                self.statusItem?.length = 90
                
                // 创建自定义视图
                let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 90, height: 22))
                self.statusItemView = view
                
                print("[调试] 准备显示倒计时状态，当前状态: \(self.isCountingDown)")
                
                // 再次确认状态，可能在延迟期间状态变化
                if self.isCountingDown {
                    self.statusItem?.button?.addSubview(view)
                    view.update(time: time, icon: icon)
                    print("[调试] 显示倒计时: 时间=\(time)")
                } else {
                    print("[调试] 最后一刻取消显示倒计时状态")
                    self.displayNormalStatusItem()
                }
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    

    

    
    // 定时关机菜单项处理
    @objc func scheduleShutdown(_ sender: AnyObject?) {
        // 显示主界面，并选择关机选项
        guard let button = statusItem?.button else { return }
        
        // 显示主界面
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // 发送通知以选择关机选项
        NotificationCenter.default.post(name: Notification.Name("SelectShutdownAction"), object: nil)
    }
    
    // 定时休眠菜单项处理
    @objc func scheduleSleep(_ sender: AnyObject?) {
        // 显示主界面，并选择休眠选项
        guard let button = statusItem?.button else { return }
        
        // 显示主界面
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // 发送通知以选择休眠选项
        NotificationCenter.default.post(name: Notification.Name("SelectSleepAction"), object: nil)
    }
    
    // 取消定时菜单项处理
    @objc func cancelSchedule(_ sender: AnyObject?) {
        // 取消当前的定时任务
        if isCountingDown {
            isCountingDown = false
            remainingSeconds = 0
            
            // 停止定时器
            stopMenuBarUpdateTimer()
            
            // 恢复正常状态
            displayNormalStatusItem()
            
            // 显示通知
            let notification = NSUserNotification()
            notification.title = SettingsManager.shared.localizedString(for: "cancel_notification_title", defaultValue: "定时已取消")
            notification.informativeText = SettingsManager.shared.localizedString(for: "cancel_notification_text", defaultValue: "定时关机/休眠任务已取消")
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    @objc func openSettings(_ sender: AnyObject?) {
        // 如果设置窗口控制器不存在，创建一个
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        
        // 显示设置窗口并激活
        settingsWindowController?.showWindow(sender)
        settingsWindowController?.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // 显示关于对话框
    @objc func showAbout(_ sender: AnyObject?) {
        // 创建并显示关于对话框
        let alert = NSAlert()
        alert.messageText = getLocalizedString(for: "app_title", defaultValue: "定时关机/休眠工具")
        alert.informativeText = "版本: 1.0\n© 2025 Hu Gang"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // 获取本地化字符串
    func getLocalizedString(for key: String, defaultValue: String) -> String {
        return SettingsManager.shared.localizedString(for: key, defaultValue: defaultValue)
    }
    
    // 启动菜单栏更新定时器
    func startMenuBarUpdateTimer() {
        // 停止现有定时器（如果有）
        stopMenuBarUpdateTimer()
        
        // 如果不在倒计时状态，不启动定时器
        if !isCountingDown {
            print("[调试] 取消启动定时器，因为当前不在倒计时状态")
            return
        }
        
        print("[调试] 启动菜单栏更新定时器")
        
        // 创建新定时器，每秒更新一次
        menuBarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate() // 自我清理
                return
            }
            
            // 再次检查状态，防止在非倒计时状态下更新
            if !self.isCountingDown {
                timer.invalidate()
                self.menuBarUpdateTimer = nil
                print("[调试] 定时器自动停止，当前状态不再倒计时")
                self.displayNormalStatusItem() // 强制恢复正常状态
                return
            }
            
            self.updateMenuBarDisplay()
        }
        
        // 确保定时器添加到当前运行循环
        RunLoop.current.add(menuBarUpdateTimer!, forMode: .common)
    }
    
    // 停止菜单栏更新定时器
    func stopMenuBarUpdateTimer() {
        // 在主线程停止定时器
        DispatchQueue.main.async {
            // 取消所有正在的延迟调用
            DispatchQueue.main.async {
                self.menuBarUpdateTimer?.invalidate()
                self.menuBarUpdateTimer = nil
                print("[调试] 偏然停止所有菜单栏定时器")
            }
        }
    }
    
    // 更新菜单栏显示
    private func updateMenuBarDisplay() {
        // 进行安全检查，确保当前真的在倒计时状态
        if !isCountingDown {
            print("[调试] 取消菜单栏更新，当前不在倒计时状态")
            // 强制恢复正常状态
            DispatchQueue.main.async {
                self.displayNormalStatusItem()
            }
            return
        }
        
        // 如果正在倒计时
        // 格式化倒计时时间
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        let formattedTime = String(format: "%d:%02d", minutes, seconds)
        
        // 准备图标
        var icon: NSImage? = nil
        if selectedAction == "关机" {
            // 关机模式
            let powerIcon = NSImage(systemSymbolName: "power", accessibilityDescription: "Shutdown")
            powerIcon?.size = NSSize(width: 18, height: 18)
            icon = powerIcon
        } else {
            // 休眠模式
            let sleepIcon = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Sleep")
            sleepIcon?.size = NSSize(width: 18, height: 18)
            icon = sleepIcon
        }
        
        // 在主线程中更新UI，但再次检查状态
        DispatchQueue.main.async {
            // 最终一次检查状态
            if !self.isCountingDown {
                print("[调试] 取消菜单栏更新，在开始显示前检测到状态变化")
                self.displayNormalStatusItem()
                return
            }
            
            if self.statusItemView != nil {
                // 只更新已有视图的内容
                self.statusItemView?.update(time: formattedTime, icon: icon)
            } else {
                // 首次显示倒计时
                self.displayCountdownView(time: formattedTime, icon: icon)
            }
        }
    }
    
    // 格式化倒计时时间
    func formatTimeRemaining(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
