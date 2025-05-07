import Cocoa
import SwiftUI
import Combine
import Foundation

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[调试] 应用程序启动")
        // 隐藏dock图标
        NSApp.setActivationPolicy(.accessory)
        
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
        if let customIcon = NSImage(named: "icon_white") {
            icon = customIcon
        } else {
            // 使用系统图标
            icon = NSImage(systemSymbolName: "power", accessibilityDescription: "Shutdown")
        }
        
        icon?.size = NSSize(width: 18, height: 18)
        self.originalIcon = icon
        
        // 设置状态栏图标
        statusItem?.button?.image = icon
        
        // 设置点击动作
        statusItem?.button?.action = #selector(togglePopover(_:))
        
        print("[调试] 创建状态栏图标: \(icon != nil)")
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
        
        // 设置点击动作
        statusItem?.button?.action = #selector(togglePopover(_:))
        
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
