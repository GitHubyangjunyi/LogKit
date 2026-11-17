import Foundation
import os
import Testing
@testable import LogKit

@Suite(.serialized)
struct LogKitTests {

    @Test func categorizedLoggingDoesNotCrash() async {
        await Log.shared.setEnabled(true)
        await Log.shared.network("网络请求测试")
        await Log.shared.network("错误测试", type: .error)
        await Log.shared.bluetooth("蓝牙测试")
        await Log.shared.viewControllerLife("生命周期测试")
        await Log.shared.debug(.performance, "调试测试")
    }

    @Test func disabledDropsMessagesAndIntervals() async {
        await Log.shared.setEnabled(false)
        let state = await Log.shared.beginInterval("test")
        #expect(state == nil)
        await Log.shared.endInterval("test", state: nil)
        await Log.shared.emitEvent("test")
        await Log.shared.network("should be dropped")
        await Log.shared.setEnabled(true)
    }

    @Test func signpostLifecycle() async {
        await Log.shared.setEnabled(true)
        let state = await Log.shared.beginInterval("测试耗时", category: .performance, "id=1")
        #expect(state != nil)
        await Log.shared.endInterval("测试耗时", category: .performance, state: state)
        await Log.shared.emitEvent("测试瞬时事件")

        let netState = await Log.shared.beginNetworkRequest(method: "GET", url: "https://example.com")
        #expect(netState != nil)
        await Log.shared.endNetworkRequest(method: "GET", url: "https://example.com", state: netState)
    }

    @Test func fileLoggerWritesReadsAndClears() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".log")
        let logger = FileLogger(fileURL: url, alsoPrints: false)

        await logger.log("第一条日志")
        let content = await logger.readLog()
        #expect(content?.contains("第一条日志") == true)
        #expect(content?.contains("===== 新会话") == true)

        await logger.clear()
        let cleared = await logger.readLog()
        #expect(cleared == nil)
    }

    @Test func fileLoggerFileNameInit() {
        let logger = FileLogger(fileName: "PitchAxisDiag.log", alsoPrints: false)
        #expect(logger.fileURL.lastPathComponent == "PitchAxisDiag.log")
    }

    @Test func fileLoggerFlushAndTruncation() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".log")
        let logger = FileLogger(fileURL: url, alsoPrints: false, maxFileSize: 200)

        for i in 0..<50 {
            await logger.log("第 \(i) 条日志，内容足够长用来撑爆文件大小限制")
        }
        await logger.flush()

        let content = await logger.readLog()
        #expect(content != nil)
        #expect(content!.utf8.count < 200 + 200)
        #expect(content!.contains("已截断"))
        #expect(content!.contains("第 49 条日志"))
    }

    @Test func instancesAreIndependent() async {
        let appLog = Log(subsystem: "com.app")
        let frameworkLog = Log(subsystem: "com.framework")

        await frameworkLog.setEnabled(false)

        #expect(await appLog.subsystem == "com.app")
        #expect(await frameworkLog.subsystem == "com.framework")
        #expect(await frameworkLog.beginInterval("x") == nil)
        #expect(await appLog.beginInterval("x") != nil)
    }

    @Test func subsystemIsConfigurable() async {
        let old = await Log.shared.subsystem
        await Log.shared.setSubsystem("com.test.logkit")
        let subsystem = await Log.shared.subsystem
        #expect(subsystem == "com.test.logkit")
        await Log.shared.network("使用新 subsystem")
        await Log.shared.setSubsystem(old)
    }
}
