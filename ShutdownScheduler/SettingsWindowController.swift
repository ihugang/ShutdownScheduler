import Cocoa

class SettingsWindowController: NSWindowController {
    
    // 语言选择下拉菜单
    @IBOutlet weak var languagePopup: NSPopUpButton!
    
    // 开机启动复选框
    @IBOutlet weak var launchAtLoginCheckbox: NSButton!
    
    // 标签文本
    @IBOutlet weak var languageLabel: NSTextField!
    @IBOutlet weak var launchAtLoginLabel: NSTextField!
    @IBOutlet weak var settingsTitleLabel: NSTextField!
    
    // 关闭按钮
    @IBOutlet weak var closeButton: NSButton!
    
    override var windowNibName: NSNib.Name? {
        return "SettingsWindow"
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // 设置窗口标题
        self.window?.title = "设置"
        
        // 初始化UI
        setupUI()
        
        // 加载当前设置
        loadSettings()
        
        // 注册语言变更通知
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(handleLanguageChanged), 
                                              name: Notification.Name("LanguageChanged"), 
                                              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        // 设置标题
        settingsTitleLabel.stringValue = "应用程序设置"
        
        // 设置语言标签
        languageLabel.stringValue = "界面语言："
        
        // 设置语言选项
        languagePopup.removeAllItems()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.displayName)
        }
        
        // 设置开机启动标签
        launchAtLoginLabel.stringValue = "开机自动启动："
        
        // 设置窗口大小
        self.window?.setContentSize(NSSize(width: 350, height: 200))
        
        // 更新UI文本
        updateUIText()
    }
    
    private func loadSettings() {
        // 加载语言设置
        if let index = AppLanguage.allCases.firstIndex(of: SettingsManager.shared.currentLanguage) {
            languagePopup.selectItem(at: index)
        }
        
        // 加载开机启动设置
        launchAtLoginCheckbox.state = SettingsManager.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func handleLanguageChanged() {
        updateUIText()
    }
    
    private func updateUIText() {
        // 根据当前语言更新UI文本
        self.window?.title = getLocalizedString(for: "settings", defaultValue: "设置")
        settingsTitleLabel.stringValue = getLocalizedString(for: "app_settings", defaultValue: "应用程序设置")
        languageLabel.stringValue = getLocalizedString(for: "interface_language", defaultValue: "界面语言：")
        launchAtLoginLabel.stringValue = getLocalizedString(for: "launch_at_login", defaultValue: "开机自动启动：")
        
        // 更新关闭按钮文本
        if let closeButton = closeButton {
            closeButton.title = getLocalizedString(for: "close_button", defaultValue: "关闭")
        }
    }
    
    private func getLocalizedString(for key: String, defaultValue: String) -> String {
        return SettingsManager.shared.localizedString(for: key, defaultValue: defaultValue)
    }
    
    // MARK: - 事件处理
    
    @IBAction func languageChanged(_ sender: NSPopUpButton) {
        if let selectedLanguage = AppLanguage.allCases[safe: sender.indexOfSelectedItem] {
            SettingsManager.shared.currentLanguage = selectedLanguage
        }
    }
    
    @IBAction func launchAtLoginChanged(_ sender: NSButton) {
        SettingsManager.shared.launchAtLogin = (sender.state == .on)
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.window?.close()
    }
}

// 安全数组访问扩展
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
