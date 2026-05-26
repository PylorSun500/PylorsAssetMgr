import Foundation

actor FileMonitorService {
    /// 占位服务 —— FSEvents 将在后续迭代中集成
    /// 当前使用手动刷新 (Cmd+R) 替代自动文件变更监听
    func start(root: URL) -> AsyncStream<String> {
        AsyncStream { _ in }
    }

    func stop() {}
}
