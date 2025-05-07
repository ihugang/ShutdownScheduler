// main.swift
// 传统 AppDelegate 菜单栏应用入口
import Cocoa

_ = NSApplication.shared
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
