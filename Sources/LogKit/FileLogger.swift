//
//  FileLogger.swift
//  LogKit
//
//  Created by 杨俊艺 on 2026/11/13.
//

import Foundation

/// 文件日志：除控制台外同时写入沙盒文件默认写入 `Documents/LogKit.log`（App 开启 `UIFileSharingEnabled` 后可在"文件"App / Finder 中直接取回）
public actor FileLogger {
	
    public static let shared = FileLogger()
	
    public nonisolated let fileURL: URL
	
    public nonisolated let alsoPrints: Bool
	
    public nonisolated let maxFileSize: UInt64
	
    private let formatter = DateFormatter()
    private var didMarkSession = false
    private var fileHandle: FileHandle?
	
    /// - Parameters:
    ///   - fileURL: 日志文件完整路径，`nil` 时使用默认位置 `Documents/LogKit.log`
    ///   - alsoPrints: 是否同时 `print` 到控制台
    ///   - maxFileSize: 文件大小上限（字节），默认 5 MB
    public init(fileURL: URL? = nil, alsoPrints: Bool = true, maxFileSize: UInt64 = 5 * 1024 * 1024) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LogKit.log")
        self.alsoPrints = alsoPrints
        self.maxFileSize = maxFileSize
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
    }
	
    /// 以文件名创建（写入 `Documents` 目录）
    /// - Parameters:
    ///   - fileName: 日志文件名，例如 `"PitchAxisDiag.log"`
    ///   - alsoPrints: 是否同时 `print` 到控制台
    ///   - maxFileSize: 文件大小上限（字节），默认 5 MB
    public init(fileName: String, alsoPrints: Bool = true, maxFileSize: UInt64 = 5 * 1024 * 1024) {
        self.fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        self.alsoPrints = alsoPrints
        self.maxFileSize = maxFileSize
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
    }
	
    /// 写入一条日志（自动追加时间戳和会话分隔标记，actor 内串行落盘）
    public func log(_ message: sending @autoclosure () -> String) {
        let text = message()
        if alsoPrints { print(text) }
        let timestamp = formatter.string(from: Date())
        if !didMarkSession {
            didMarkSession = true
            appendLine("===== 新会话 \(timestamp) =====")
        }
        appendLine("\(timestamp) \(text)")
    }
	
    /// 等待所有已提交的写入落盘（崩溃上报、App 退出前建议调用）
    /// - Note: actor 串行执行的天然特性：`await flush()` 返回即代表此前所有 `log` 已完成
    public func flush() {}
	
    /// 读取全部日志内容
    public func readLog() -> String? {
        (try? Data(contentsOf: fileURL)).flatMap { String(data: $0, encoding: .utf8) }
    }
	
    /// 清空日志文件
    public func clear() {
        closeHandle()
        try? FileManager.default.removeItem(at: fileURL)
        didMarkSession = false
    }
	
    private func appendLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8),
              let handle = currentHandle() else { return }
        if handle.offsetInFile > maxFileSize {
            try? handle.truncate(atOffset: 0)
            try? handle.seek(toOffset: 0)
            if let marker = "===== 日志超过大小上限，旧内容已截断 =====\n".data(using: .utf8) {
                try? handle.write(contentsOf: marker)
            }
        }
        try? handle.write(contentsOf: data)
    }
	
    private func currentHandle() -> FileHandle? {
        if let fileHandle { return fileHandle }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            _ = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return nil }
        _ = try? handle.seekToEnd()
        fileHandle = handle
        return handle
    }
	
    private func closeHandle() {
        try? fileHandle?.close()
        fileHandle = nil
    }
}
