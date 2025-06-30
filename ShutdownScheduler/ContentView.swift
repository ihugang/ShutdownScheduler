import SwiftUI
import OSLog
import Combine

struct ContentView: View {
      // 添加刷新视图的状态变量
   @State private var refreshID = UUID()
   
      // 本地化字符串辅助函数
   private func localizedString(for key: String, defaultValue: String) -> String {
      return SettingsManager.shared.localizedString(for: key, defaultValue: defaultValue)
   }
      // 状态变化回调函数类型：isCountingDown, remainingSeconds, actionType
   var countdownStateChanged: ((Bool, Int, ActionType) -> Void)? = nil
   
   init(countdownStateChanged: ((Bool, Int, ActionType) -> Void)? = nil) {
      self.countdownStateChanged = countdownStateChanged
   }
      // 添加日志记录器
   private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.ShutdownScheduler", category: "ContentView")
   
   @State private var minutes: Int = 30
   @State private var minutesString: String = "30"
   @State private var feedback: String = ""
   @State private var selectedAction: ActionType = .shutdown
   @State private var isCountingDown: Bool = false
   @State private var remainingSeconds: Int = 0
   @State private var countdownTimer: Timer? = nil
   @State private var endTime: Date? = nil
   @State private var commandOutput: String = ""
   @State private var scheduledJobLabels: [String] = []
   @State private var scheduledJobPaths: [String] = []
   @State private var isDeepSleepModeEnabled: Bool = false
      // 创建通知发布者
   private let shutdownNotification = NotificationCenter.default.publisher(for: Notification.Name("SelectShutdownAction"))
   private let sleepNotification = NotificationCenter.default.publisher(for: Notification.Name("SelectSleepAction"))
   private let refreshViewNotification = NotificationCenter.default.publisher(for: Notification.Name("RefreshContentView"))
   private let cancelAllTasksNotification = NotificationCenter.default.publisher(for: Notification.Name("CancelAllTasks"))
   
   var body: some View {
      VStack(spacing: 20) {
         Text(localizedString(for: "app_title", defaultValue: "定时关机/休眠工具"))
            .font(.headline)
            .padding(.bottom, 5)
         
         if isCountingDown {
               // 显示倒计时
            VStack(spacing: 15) {
               Text(String(format: localizedString(for: "countdown", defaultValue: "倒计时中: %@"), formatTimeRemaining(seconds: remainingSeconds)))
                  .font(.title)
                  .foregroundColor(.blue)
                  .frame(maxWidth: .infinity, alignment: .center)
               
               Text(String(format: localizedString(for: "estimated_time", defaultValue: "预计%@时间: %@"), localizedString(for: selectedAction.rawValue, defaultValue: selectedAction.rawValue), formatDate(endTime)))
                  .font(.subheadline)
                  .frame(maxWidth: .infinity, alignment: .center)
               
               Button(localizedString(for: "cancel_task", defaultValue: "取消任务")) {
                  cancelAction()
               }
               .foregroundColor(.white)
               .buttonStyle(PlainButtonStyle())
               .padding(.vertical, 8)
               .padding(.horizontal, 20)
               .background(Color.red)
               .cornerRadius(8)
               .padding(.top, 10)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
         } else {
               // 设置界面
            VStack(spacing: 15) {
                  // 输入区域 - Spin模式
               HStack {
                  Text(localizedString(for: "delay_minutes", defaultValue: "延时分钟："))
                     .frame(width: 80, alignment: .leading)
                  
                     // 减少按钮
                  Button(action: {
                     if minutes > 1 {
                        minutes -= 1
                        minutesString = "\(minutes)"
                     }
                  }) {
                     Image(systemName: "minus.circle")
                        .foregroundColor(.blue)
                  }
                  .buttonStyle(BorderlessButtonStyle())
                  
                     // 分钟数输入框
                  TextField("", text: $minutesString)
                     .textFieldStyle(PlainTextFieldStyle())
                     .multilineTextAlignment(.center)
                     .frame(width: 60)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 4)
                     .background(Color.gray.opacity(0.1))
                     .cornerRadius(6)
                     .overlay(
                        RoundedRectangle(cornerRadius: 6)
                           .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                     )
                     .onChange(of: minutesString) { newValue in
                        // 只允许数字输入
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            minutesString = filtered
                            return
                        }
                        
                        // 转换为整数并验证范围
                        if let value = Int(filtered), value >= 1 {
                            minutes = value
                        } else if !filtered.isEmpty {
                            // 如果输入无效（如空或小于1），则重置为1
                            minutes = 1
                            minutesString = "1"
                        }
                     }
                  
                     // 增加按钮
                  Button(action: {
                     minutes += 1
                     minutesString = "\(minutes)"
                  }) {
                     Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                  }
                  .buttonStyle(BorderlessButtonStyle())
                  
                  Spacer()
               }
               .frame(maxWidth: 250)
               
                  // 操作类型选择器
               HStack {
                  Text(localizedString(for: "action_type", defaultValue: "操作类型："))
                     .frame(width: 80, alignment: .leading)
                  
                  Picker("", selection: $selectedAction) {
                     Text(localizedString(for: "shutdown", defaultValue: "关机")).tag(ActionType.shutdown)
                     Text(localizedString(for: "sleep", defaultValue: "休眠")).tag(ActionType.sleep)
                  }
                  .pickerStyle(SegmentedPickerStyle())
                  .frame(width: 150)
                  
                  Spacer()
               }
               .frame(maxWidth: 250)
               
                  // 深度休眠模式开关
               Toggle(isOn: $isDeepSleepModeEnabled) {
                  Text(localizedString(for: "deep_sleep_mode", defaultValue: "深度休眠模式"))
               }
               .toggleStyle(SwitchToggleStyle())
               .frame(maxWidth: 250, alignment: .leading)
                  // 描述文字
               Text("此模式将关闭 PowerNap、网络唤醒等系统自动唤醒机制")
                  .font(.caption)
                  .foregroundColor(isDeepSleepModeEnabled ? .blue : .gray)
                  .frame(maxWidth: 250, alignment: .leading)
               
                  // 按钮
               Button(localizedString(for: "start_countdown", defaultValue: "开始倒计时")) {
                  executeAction(minutes: minutes, actionType: selectedAction)
               }
               .buttonStyle(PlainButtonStyle())
               .foregroundColor(.white)
               .padding(.vertical, 8)
               .padding(.horizontal, 20)
               .background(
                  // 使用ZStack确保只有一层背景
                  ZStack {
                     Color.blue
                  }
               )
               .cornerRadius(8)
               .padding(.top, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
         }
         
            // 反馈信息
         Text(feedback)
            .foregroundColor(.gray)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 5)
            // 添加日志显示区域
         if !commandOutput.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
               Text("命令日志:")
                  .font(.caption.bold())
                  .frame(maxWidth: .infinity, alignment: .leading)
               
               ScrollView {
                  Text(commandOutput)
                     .font(.system(.caption, design: .monospaced))
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding(8)
                     .background(Color.black.opacity(0.05))
                     .cornerRadius(8)
               }
            }
            .frame(maxHeight: 150)
            .padding(.top, 5)
            .padding(.horizontal, 5)
         }
      }
      .padding()
      .onReceive(shutdownNotification) { _ in
         selectedAction = .shutdown
         minutes = 30
            // 可选：自动开始倒计时
            // executeAction(minutes: minutes, actionType: selectedAction)
      }
      .onReceive(sleepNotification) { _ in
         selectedAction = .sleep
         minutes = 30
            // 可选：自动开始倒计时
            // executeAction(minutes: minutes, actionType: selectedAction)
      }
         // 监听刷新界面通知，当语言变化时刷新界面
      .onReceive(refreshViewNotification) { _ in
            // 强制刷新界面
            // 更新 refreshID 状态变量来触发界面刷新
         refreshID = UUID()
      }
         // 监听取消所有任务的通知
      .onReceive(cancelAllTasksNotification) { _ in
         logger.info("接收到取消所有任务的通知")
            // 取消所有计划任务
         cancelAllScheduledJobs()
            // 停止倒计时
         stopCountdown()
      }
      .onDisappear {
         stopCountdown()
      }
         // 使用 refreshID 作为整个视图的 ID，确保语言变化时视图会完全重新创建
      .id(refreshID)
   }
   
   @State private var showingAuthAlert = false
   @State private var pendingAction: (()->Void)? = nil
   
   func executeAction(minutes: Int, actionType: ActionType) {
      guard minutes > 0 else {
         feedback = "请输入有效的分钟数"
         return
      }
      let secondsDelay = minutes * 60
      commandOutput = ""
      let targetTime = Date().addingTimeInterval(TimeInterval(secondsDelay))
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: targetTime)
      let minute = calendar.component(.minute, from: targetTime)
      feedback = "即将设置\(minutes)分钟后\(actionType.rawValue)，需要您输入管理员密码"
         // 先应用深度休眠设置
      if isDeepSleepModeEnabled {
            // 深度休眠
         if actionType == .shutdown {
            scheduleOneTimeShutdownWithSleepMode(atHour: hour, minute: minute, useDeepSleep: true, minutes: minutes)
         } else {
            scheduleOneTimeSleepWithSleepMode(atHour: hour, minute: minute, useDeepSleep: true, minutes: minutes)
         }
         feedback += "（深度休眠模式已启用）"
      } else {
            // 普通休眠
         if actionType == .shutdown {
            scheduleOneTimeShutdownWithSleepMode(atHour: hour, minute: minute, useDeepSleep: false, minutes: minutes)
         } else {
            scheduleOneTimeSleepWithSleepMode(atHour: hour, minute: minute, useDeepSleep: false, minutes: minutes)
         }
         feedback += "（使用系统默认休眠设置）"
      }
         // 启动倒计时（用于UI显示，不再倒计时结束后请求密码）
      startCountdown(seconds: secondsDelay, actionType: actionType)
   }
   
      // 请求管理员权限并执行命令
   func requestAdminPrivilegesAndExecute(command: String, actionName: String, secondsDelay: Int) {
         // 先重置状态，确保处于非倒计时状态
      countdownStateChanged?(false, 0, selectedAction) // 强制通知AppDelegate重置statusItem
      isCountingDown = false
      stopCountdown()
      
         // 等待状态清除
      let group = DispatchGroup()
      group.enter()
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
         group.leave()
      }
      
      group.wait()
      
         // 执行命令
      logger.info("执行命令: \(command)")
      let script = """
        do shell script "\(command)" with administrator privileges
        """
      
      let result = runAppleScript(script: script)
      logger.info("命令执行结果: \(result.output)")
      
         // 更新命令输出
      appendToCommandOutput("执行命令: \(command)")
      appendToCommandOutput("结果: \(result.output)")
      
         // 检测是否取消了权限请求
      if result.output == "USER_CANCELED" {
         feedback = "您取消了管理员权限请求"
         
            // 再次确保重置状态
         let notificationName = Notification.Name("ForceStatusItemReset")
         NotificationCenter.default.post(name: notificationName, object: nil) // 发送强制重置通知
         
         DispatchQueue.main.async {
            self.countdownStateChanged?(false, 0, self.selectedAction)
            self.isCountingDown = false
            self.stopCountdown()
         }
         
         return
      }
      
         // 检查启动倒计时的条件
      if result.success && !result.output.isEmpty {
            // 成功执行命令，启动倒计时
         feedback = "已设置 \(secondsDelay / 60) 分钟后\(actionName)"
         
            // 清空之前的任何倒计时状态
         stopCountdown()
         
            // 等待一小段时间再开始倒计时，确保上一次的状态已清除
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
               // 开始新的倒计时
            self.startCountdown(seconds: secondsDelay, actionType: .shutdown)
         }
      } else {
            // 执行失败
         feedback = "命令执行失败"
         
            // 确保再次重置状态
         countdownStateChanged?(false, 0, selectedAction)
         isCountingDown = false
         stopCountdown()
      }
   }
   
   func cancelAction() {
         // 取消所有计划任务
      cancelAllScheduledJobs()
      
      feedback = "已取消所有计划任务"
      
         // 停止倒计时
      stopCountdown()
      
         // 通知状态变化
      countdownStateChanged?(false, 0, selectedAction)
   }
   
      // 计划一次性休眠任务
   func scheduleOneTimeSleep(atHour hour: Int, minute: Int) -> (success: Bool, output: String) {
      let timeString = String(format: "%02d:%02d", hour, minute)
      
         // 创建一个唯一的标识符
      let jobLabel = "com.app.shutdownscheduler.sleep."+UUID().uuidString
      
         // 创建临时plist文件路径
      let tempDir = FileManager.default.temporaryDirectory
      let plistPath = tempDir.appendingPathComponent("\(jobLabel).plist")
      
         // 获取当前日期并设置目标时间
      let calendar = Calendar.current
      var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
      dateComponents.hour = hour
      dateComponents.minute = minute
      dateComponents.second = 0
      
      guard let targetDate = calendar.date(from: dateComponents) else {
         return (false, "无法创建目标日期")
      }
      
         // 如果目标时间已经过去，则设置为明天的同一时间
      var finalDate = targetDate
      if finalDate < Date() {
         finalDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
      }
      
         // 创建plist内容
      let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(jobLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/pmset</string>
                <string>sleepnow</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(calendar.component(.hour, from: finalDate))</integer>
                <key>Minute</key>
                <integer>\(calendar.component(.minute, from: finalDate))</integer>
            </dict>
        </dict>
        </plist>
        """
      
         // 写入plist文件
      do {
         try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
      } catch {
         return (false, "无法创建plist文件: \(error.localizedDescription)")
      }
      
         // 使用launchctl加载plist
      let script = """
        do shell script "launchctl load \(plistPath.path)" with administrator privileges
        """
      
      let result = runAppleScript(script: script)
      
      if result.success {
            // 保存任务标识符以便后续取消
         scheduledJobLabels.append(jobLabel)
         scheduledJobPaths.append(plistPath.path)
      }
      
      appendToCommandOutput("计划休眠任务: \(timeString)")
      appendToCommandOutput("结果: \(result.output.isEmpty ? "成功" : result.output)")
      
      return result
   }
   
      // 计划一次性关机任务
   func scheduleOneTimeShutdown(atHour hour: Int, minute: Int) -> (success: Bool, output: String) {
      let timeString = String(format: "%02d:%02d", hour, minute)
      
         // 创建一个唯一的标识符
      let jobLabel = "com.app.shutdownscheduler.shutdown."+UUID().uuidString
      
         // 创建临时plist文件路径
      let tempDir = FileManager.default.temporaryDirectory
      let plistPath = tempDir.appendingPathComponent("\(jobLabel).plist")
      
         // 获取当前日期并设置目标时间
      let calendar = Calendar.current
      var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
      dateComponents.hour = hour
      dateComponents.minute = minute
      dateComponents.second = 0
      
      guard let targetDate = calendar.date(from: dateComponents) else {
         return (false, "无法创建目标日期")
      }
      
         // 如果目标时间已经过去，则设置为明天的同一时间
      var finalDate = targetDate
      if finalDate < Date() {
         finalDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
      }
      
         // 创建plist内容
      let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(jobLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/sbin/shutdown</string>
                <string>-h</string>
                <string>now</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(calendar.component(.hour, from: finalDate))</integer>
                <key>Minute</key>
                <integer>\(calendar.component(.minute, from: finalDate))</integer>
            </dict>
        </dict>
        </plist>
        """
      
         // 写入plist文件
      do {
         try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
      } catch {
         return (false, "无法创建plist文件: \(error.localizedDescription)")
      }
      
         // 使用launchctl加载plist
      let script = """
        do shell script "launchctl load \(plistPath.path)" with administrator privileges
        """
      
      let result = runAppleScript(script: script)
      
      if result.success {
            // 保存任务标识符以便后续取消
         scheduledJobLabels.append(jobLabel)
         scheduledJobPaths.append(plistPath.path)
      }
      
      appendToCommandOutput("计划关机任务: \(timeString)")
      appendToCommandOutput("结果: \(result.output.isEmpty ? "成功" : result.output)")
      
      return result
   }
   
      // 取消所有计划任务
   func cancelAllScheduledJobs() {
      var allSuccess = true
      var output = ""
      
         // 如果没有计划任务，直接返回
      if scheduledJobLabels.isEmpty {
         appendToCommandOutput("没有计划任务需要取消")
         return
      }
      
         // 遍历所有计划任务
      for (index, jobLabel) in scheduledJobLabels.enumerated() {
         let plistPath = scheduledJobPaths[index]
         
            // 卸载任务
         let script = """
            do shell script "launchctl unload \(plistPath)" with administrator privileges
            """
         
         let result = runAppleScript(script: script)
         
         if !result.success {
            allSuccess = false
            output += "\n\(jobLabel): \(result.output)"
         }
         
            // 尝试删除plist文件
         do {
            try FileManager.default.removeItem(atPath: plistPath)
         } catch {
            output += "\n无法删除文件 \(plistPath): \(error.localizedDescription)"
         }
      }
      
         // 清空任务列表
      scheduledJobLabels.removeAll()
      scheduledJobPaths.removeAll()
      
      appendToCommandOutput("取消所有计划任务")
      appendToCommandOutput("结果: " + (output.isEmpty ? "成功" : output))
   }
   
      // 开始倒计时
   func startCountdown(seconds: Int, actionType: ActionType) {
         // 停止之前的倒计时（如果有）
      stopCountdown()
      
      remainingSeconds = seconds
      isCountingDown = true
      
         // 计算结束时间
      endTime = Date().addingTimeInterval(TimeInterval(seconds))
      
         // 通知状态变化
      print("[调试] ContentView: 开始倒计时，触发回调函数")
      countdownStateChanged?(true, remainingSeconds, selectedAction)
      
         // 创建定时器，每秒更新一次
      countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
         
         if remainingSeconds > 0 {
            remainingSeconds -= 1
               // 通知状态变化
            print("[调试] ContentView: 倒计时更新，剩余时间: \(remainingSeconds)")
            countdownStateChanged?(true, remainingSeconds, selectedAction)
         } else {
               // 倒计时结束，执行相应操作
            executeActionWhenCountdownEnds(actionType: actionType)
            stopCountdown()
         }
      }
   }
   
      // 停止倒计时
   func stopCountdown() {
      countdownTimer?.invalidate()
      countdownTimer = nil
      remainingSeconds = 0
      isCountingDown = false
      
         // 通知状态变化
      print("[调试] ContentView: 停止倒计时，触发回调函数")
      countdownStateChanged?(false, 0, selectedAction)
   }
   
      // 倒计时结束时执行相应操作
   func executeActionWhenCountdownEnds(actionType: ActionType) {
      switch actionType {
         case .shutdown:
               // 使用AppleScript直接执行关机命令，避免优先级反转
            let script = "tell application \"Finder\" to shut down"
            
               // 在主线程上执行AppleScript
            let result = runAppleScript(script: script)
            
            self.logger.info("执行关机命令结果: \(result.output)")
            self.appendToCommandOutput("执行关机命令")
            
            if result.success {
               self.appendToCommandOutput("结果: 成功")
            } else {
               self.appendToCommandOutput("结果: \(result.output)")
               self.feedback = "关机命令执行失败: \(result.output)"
            }
            
         case .sleep:
               // 使用AppleScript直接执行休眠命令，避免优先级反转
            let script = "tell application \"Finder\" to sleep"
            
               // 在主线程上执行AppleScript
            let result = runAppleScript(script: script)
            
            self.logger.info("执行休眠命令结果: \(result.output)")
            self.appendToCommandOutput("执行休眠命令")
            
            if result.success {
               self.appendToCommandOutput("结果: 成功")
            } else {
               self.appendToCommandOutput("结果: \(result.output)")
               self.feedback = "休眠命令执行失败: \(result.output)"
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
   
      // 格式化日期
   func formatDate(_ date: Date?) -> String {
      guard let date = date else { return "--" }
      
      let formatter = DateFormatter()
      formatter.dateFormat = "HH:mm:ss"
      return formatter.string(from: date)
   }
   
      // 运行AppleScript并返回结果
   func runAppleScript(script: String) -> (success: Bool, output: String) {
         // 使用NSAppleScript更可靠地处理取消操作
      let appleScript = NSAppleScript(source: script)
      var errorDict: NSDictionary?
      var descriptor: NSAppleEventDescriptor?
      DispatchQueue.global(qos: .userInitiated).sync {
         descriptor = appleScript?.executeAndReturnError(&errorDict)
      }
      
         // 如果有错误，检查是否是取消操作
      if let errorDict = errorDict, let error = errorDict[NSAppleScript.errorNumber] as? NSNumber {
         let errorCode = error.intValue
         let errorMessage = errorDict[NSAppleScript.errorMessage] as? String ?? "未知错误"
         
            // -128 是用户取消操作的错误代码
         if errorCode == -128 {
            self.logger.info("用户取消了操作")
            return (false, "USER_CANCELED")
         }
         
         self.logger.error("错误\(errorCode): \(errorMessage)")
         return (false, "\(errorMessage) (\(errorCode))")
      }
      
         // 如果没有错误但也没有结果
      guard let descriptor = descriptor else {
         return (true, "")
      }
      
         // 返回结果
      let output = descriptor.stringValue ?? ""
      
         // 额外检测权限失败场景
      if output.lowercased().contains("not privileged") || output.lowercased().contains("permission") {
         return (false, "权限不足，命令未执行")
      }
      
      return (true, output)
   }
   
      // 运行终端命令（已弃用，使用runPrivilegedCommands替代）
   func runTerminalCommand(_ command: String, log: String, needsPrivilege: Bool = false) {
      logger.info("\(log): \(command)")
      let script: String
      if needsPrivilege {
         script = """
          do shell script "\(command)" with administrator privileges
          """
      } else {
         script = """
          do shell script "\(command)"
          """
      }
      let result = runAppleScript(script: script)
      appendToCommandOutput("\(log): \(command)")
      appendToCommandOutput("结果: \(result.output)")
   }
      // 新增：以管理员权限一次执行多条命令
   func runPrivilegedCommands(_ commands: [String], log: String) {
      let joined = commands.joined(separator: " && ")
      let escaped = joined.replacingOccurrences(of: "\"", with: "\\\"")
      let script = """
      do shell script "sh -c \\\"\(escaped)\\\"" with administrator privileges
      """
      let result = runAppleScript(script: script)
      appendToCommandOutput("🔐 \(log)")
      appendToCommandOutput("结果: \(result.output)")
   }
   
      // 新增：带深度休眠模式的关机任务调度
   func scheduleOneTimeShutdownWithSleepMode(atHour hour: Int, minute: Int, useDeepSleep: Bool, minutes: Int) {
      let calendar = Calendar.current
      var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
      dateComponents.hour = hour
      dateComponents.minute = minute
      dateComponents.second = 0
      guard let targetDate = calendar.date(from: dateComponents) else {
         feedback = "无法创建目标日期"
         return
      }
      var finalDate = targetDate
      if finalDate < Date() {
         finalDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
      }
      let jobLabel = "com.app.shutdownscheduler.shutdown."+UUID().uuidString
      let tempDir = FileManager.default.temporaryDirectory
      let plistPath = tempDir.appendingPathComponent("\(jobLabel).plist")
      let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(jobLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/sbin/shutdown</string>
                <string>-h</string>
                <string>now</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(calendar.component(.hour, from: finalDate))</integer>
                <key>Minute</key>
                <integer>\(calendar.component(.minute, from: finalDate))</integer>
            </dict>
        </dict>
        </plist>
        """
      do {
         try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
      } catch {
         feedback = "无法创建plist文件: \(error.localizedDescription)"
         return
      }
         // 构造命令
      var commands: [String] = []
      if useDeepSleep {
         commands.append("pmset -a powernap 0")
         commands.append("pmset -a tcpkeepalive 0")
         commands.append("pmset -a womp 0")
         commands.append("pmset -a darkwakes 0")
         commands.append("pmset -a hibernatemode 25")
      } else {
         commands.append("pmset -a powernap 1")
         commands.append("pmset -a tcpkeepalive 1")
         commands.append("pmset -a womp 1")
         commands.append("pmset -a darkwakes 1")
         commands.append("pmset -a hibernatemode 3")
      }
      commands.append("launchctl load \(plistPath.path)")
      runPrivilegedCommands(commands, log: "设置关机任务及休眠模式")
      scheduledJobLabels.append(jobLabel)
      scheduledJobPaths.append(plistPath.path)
      feedback = "已设置 \(minutes) 分钟后关机" + (useDeepSleep ? "（深度休眠模式已启用）" : "（使用系统默认休眠设置）")
   }
   
      // 新增：带深度休眠模式的休眠任务调度
   func scheduleOneTimeSleepWithSleepMode(atHour hour: Int, minute: Int, useDeepSleep: Bool, minutes: Int) {
      let calendar = Calendar.current
      var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
      dateComponents.hour = hour
      dateComponents.minute = minute
      dateComponents.second = 0
      guard let targetDate = calendar.date(from: dateComponents) else {
         feedback = "无法创建目标日期"
         return
      }
      var finalDate = targetDate
      if finalDate < Date() {
         finalDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
      }
      let jobLabel = "com.app.shutdownscheduler.sleep."+UUID().uuidString
      let tempDir = FileManager.default.temporaryDirectory
      let plistPath = tempDir.appendingPathComponent("\(jobLabel).plist")
      let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(jobLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/pmset</string>
                <string>sleepnow</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key>
                <integer>\(calendar.component(.hour, from: finalDate))</integer>
                <key>Minute</key>
                <integer>\(calendar.component(.minute, from: finalDate))</integer>
            </dict>
        </dict>
        </plist>
        """
      do {
         try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
      } catch {
         feedback = "无法创建plist文件: \(error.localizedDescription)"
         return
      }
         // 构造命令
      var commands: [String] = []
      if useDeepSleep {
         commands.append("pmset -a powernap 0")
         commands.append("pmset -a tcpkeepalive 0")
         commands.append("pmset -a womp 0")
         commands.append("pmset -a darkwakes 0")
         commands.append("pmset -a hibernatemode 25")
      } else {
         commands.append("pmset -a powernap 1")
         commands.append("pmset -a tcpkeepalive 1")
         commands.append("pmset -a womp 1")
         commands.append("pmset -a darkwakes 1")
         commands.append("pmset -a hibernatemode 3")
      }
      commands.append("launchctl load \(plistPath.path)")
      runPrivilegedCommands(commands, log: "设置休眠任务及休眠模式")
      scheduledJobLabels.append(jobLabel)
      scheduledJobPaths.append(plistPath.path)
      feedback = "已设置 \(minutes) 分钟后休眠" + (useDeepSleep ? "（深度休眠模式已启用）" : "（使用系统默认休眠设置）")
   }
   
      // 添加命令输出到日志区域
   func appendToCommandOutput(_ text: String) {
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
      commandOutput += "[\(timestamp)] \(text)\n"
   }
}

   // 应用深度休眠设置和恢复默认休眠设置，移至 ContentView 内部

extension ContentView {
      // 保留 applyDeepSleepMode 和 revertDefaultSleepMode 以供界面单独调用
   func applyDeepSleepMode() {
      runPrivilegedCommands([
         "pmset -a powernap 0",
         "pmset -a tcpkeepalive 0",
         "pmset -a womp 0",
         "pmset -a darkwakes 0",
         "pmset -a hibernatemode 25"
      ], log: "应用深度休眠设置")
   }
   func revertDefaultSleepMode() {
      runPrivilegedCommands([
         "pmset -a powernap 1",
         "pmset -a tcpkeepalive 1",
         "pmset -a womp 1",
         "pmset -a darkwakes 1",
         "pmset -a hibernatemode 3"
      ], log: "恢复默认休眠设置")
   }
}
