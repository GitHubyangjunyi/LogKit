//
//  Log.swift
//  LogKit
//
//  Created by 杨俊艺 on 2026/11/13.
//

import Foundation
import os

/// LogKit 日志系统入口
///
/// 基于 `os.Logger` 的分类日志 + `OSSignposter` 路标事件跟踪：
/// - 日志写入 unified logging system，可在 Console.app / `log` 命令中按 subsystem + category 过滤
/// - 默认 Debug 构建开启、Release 构建关闭，运行时可通过 `setEnabled(_:)` 覆盖（例如生产环境远程排障）
/// - 消息闭包在 actor 内惰性求值，日志关闭时不会构造字符串
/// - 以 actor 保证 Swift 6 并发安全，调用方通过 `await`（同步上下文用 `Task { await ... }`）调用
public actor Log {
	
	/// 共享实例（App 使用）
	public static let shared = Log()
	
	/// 子系统标识
	public private(set) var subsystem: String
	
	/// 全局开关，默认开启，可通过 `setEnabled(_:)` 关闭
	public private(set) var isEnabled = true
	
	private var loggers: [LogCategory: Logger] = [:]
	private var signposters: [LogCategory: OSSignposter] = [:]
	
	/// 创建独立实例（框架使用方应创建并持有自己的实例，与 App 的 `shared` 互不干扰：
	/// 各自独立的开关、subsystem 和 logger 缓存）
	/// - Parameter subsystem: 子系统标识，`nil` 时使用宿主 App 的 Bundle ID
	public init(subsystem: String? = nil) {
		self.subsystem = subsystem ?? Bundle.main.bundleIdentifier ?? "com.logkit.unknown"
	}
	
	/// 设置子系统标识（设置后会重建内部 logger），请在 App 启动后尽早调用
	public func setSubsystem(_ subsystem: String) {
		self.subsystem = subsystem
		loggers.removeAll()
		signposters.removeAll()
	}
	
	/// 设置全局开关
	public func setEnabled(_ isEnabled: Bool) {
		self.isEnabled = isEnabled
	}
	
	// MARK: - 通用日志
	/// 记录一条分类日志
	/// - Parameters:
	///   - category: 日志分类
	///   - type: 日志级别。`.default` 及以上会持久化；`.debug` / `.info` 仅保留在内存缓冲区
	///   - message: 日志内容（闭包惰性求值，日志关闭时不会构造字符串）
	public func log(_ category: LogCategory, type: OSLogType = .default, _ message: sending @autoclosure () -> String) {
		guard isEnabled else { return }
		let text = message()
		logger(for: category).log(level: type, "\(text, privacy: .public)")
	}
	
	/// 记录不持久化的调试日志（`.debug` 级别）
	public func debug(_ category: LogCategory, _ message: sending @autoclosure () -> String) {
		guard isEnabled else { return }
		let text = message()
		logger(for: category).log(level: .debug, "\(text, privacy: .public)")
	}
	
	// MARK: - 分类便捷方法
	/// 网络日志
	public func network(_ message: sending @autoclosure () -> String, type: OSLogType = .default) {
		guard isEnabled else { return }
		let text = message()
		logger(for: .network).log(level: type, "\(text, privacy: .public)")
	}
	
	/// 蓝牙日志
	public func bluetooth(_ message: sending @autoclosure () -> String, type: OSLogType = .default) {
		guard isEnabled else { return }
		let text = message()
		logger(for: .bluetooth).log(level: type, "\(text, privacy: .public)")
	}
	
	/// 视图控制器生命周期日志
	public func viewControllerLife(_ message: sending @autoclosure () -> String, type: OSLogType = .default) {
		guard isEnabled else { return }
		let text = message()
		logger(for: .viewControllerLife).log(level: type, "\(text, privacy: .public)")
	}
	
	// MARK: - Signpost 路标持续事件
	/// 开始一段路标持续事件
	/// - Returns: 事件状态，需传给对应的 `endInterval`；日志关闭时返回 `nil`
	@discardableResult
	public func beginInterval(_ name: StaticString, category: LogCategory = .pointsOfInterest, _ message: sending @autoclosure () -> String = "") -> OSSignpostIntervalState? {
		guard isEnabled else { return nil }
		let text = message()
		return signposter(for: category).beginInterval(name, "\(text, privacy: .public)")
	}
	
	/// 结束一段路标持续事件
	public func endInterval(_ name: StaticString, category: LogCategory = .pointsOfInterest, state: OSSignpostIntervalState?, _ message: sending @autoclosure () -> String = "") {
		guard isEnabled, let state else { return }
		let text = message()
		signposter(for: category).endInterval(name, state, "\(text, privacy: .public)")
	}
	
	/// 记录路标瞬时事件（Instruments → Time Profiler → Points of Interest）
	public func emitEvent(_ name: StaticString, category: LogCategory = .pointsOfInterest, _ message: sending @autoclosure () -> String = "") {
		guard isEnabled else { return }
		let text = message()
		signposter(for: category).emitEvent(name, "\(text, privacy: .public)")
	}
	
	// MARK: - 网络请求耗时衡量
	/// 开始一次网络请求计时（GET / POST 通用，并发请求由系统分配的 signpost id 自动区分）
	@discardableResult
	public func beginNetworkRequest(method: String, url: String) -> OSSignpostIntervalState? {
		guard isEnabled else { return nil }
		return signposter(for: .network).beginInterval("网络请求耗时", "\(method) \(url, privacy: .public)")
	}
	
	/// 结束一次网络请求计时
	public func endNetworkRequest(method: String, url: String, state: OSSignpostIntervalState?) {
		guard isEnabled, let state else { return }
		signposter(for: .network).endInterval("网络请求耗时", state, "\(method) \(url, privacy: .public)")
	}
	
	private func logger(for category: LogCategory) -> Logger {
		if let logger = loggers[category] { return logger }
		let logger = Logger(subsystem: subsystem, category: category.rawValue)
		loggers[category] = logger
		return logger
	}
	
	private func signposter(for category: LogCategory) -> OSSignposter {
		if let signposter = signposters[category] { return signposter }
		let signposter = OSSignposter(subsystem: subsystem, category: category.rawValue)
		signposters[category] = signposter
		return signposter
	}
}
