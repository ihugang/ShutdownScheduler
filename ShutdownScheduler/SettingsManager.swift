import Foundation
import ServiceManagement
import os.log

enum AppLanguage: String, CaseIterable {
    case auto = "自动"
    case english = "English"
    case simplifiedChinese = "简体中文"
    
    var localeIdentifier: String? {
        switch self {
        case .auto:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let languageKey = "AppLanguagePreference"
    private let launchAtLoginKey = "LaunchAtLogin"
    
    // 当前语言设置
    var currentLanguage: AppLanguage {
        get {
            if let savedValue = defaults.string(forKey: languageKey),
               let language = AppLanguage(rawValue: savedValue) {
                return language
            }
            return .auto
        }
        set {
            defaults.set(newValue.rawValue, forKey: languageKey)
            NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        }
    }
    
    // 开机启动设置
    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: launchAtLoginKey)
        }
        set {
            defaults.set(newValue, forKey: launchAtLoginKey)
            updateLoginItemStatus(enabled: newValue)
        }
    }
    
    private init() {
        // 初始化默认值
        if defaults.object(forKey: languageKey) == nil {
            defaults.set(AppLanguage.auto.rawValue, forKey: languageKey)
        }
        
        if defaults.object(forKey: launchAtLoginKey) == nil {
            defaults.set(false, forKey: launchAtLoginKey)
        }
    }
    
    // 更新开机启动状态
    private func updateLoginItemStatus(enabled: Bool) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app.ShutdownScheduler", category: "SettingsManager")
        
        // 使用现代 API 设置登录项
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用 SMAppService
            let appService = SMAppService.mainApp
            do {
                if enabled {
                    if appService.status == .enabled {
                        try appService.unregister()
                    }
                    try appService.register()
                    logger.info("成功添加到登录项")
                } else {
                    if appService.status == .enabled {
                        try appService.unregister()
                        logger.info("成功从登录项移除")
                    }
                }
            } catch {
                logger.error("设置登录项失败: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 及更早版本
            logger.warning("当前系统版本不支持自动启动设置，需要手动添加到登录项")
            // 显示提示给用户，告知需要手动设置
            let notification = NSUserNotification()
            notification.title = "自动启动设置"
            notification.informativeText = "请在系统偏好设置 > 用户与群组 > 登录项中手动添加本应用"
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    // 获取当前语言的本地化字符串
    func localizedString(for key: String, defaultValue: String) -> String {
        guard let languageCode = currentLanguage.localeIdentifier else {
            // 自动模式，使用系统语言
            return NSLocalizedString(key, comment: "")
        }
        
        // 指定语言
        let path = Bundle.main.path(forResource: languageCode, ofType: "lproj")
        if let path = path, let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
        }
        
        return defaultValue
    }
}
