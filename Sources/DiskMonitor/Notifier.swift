import Foundation
import UserNotifications

/// 系统通知（macOS 10.14+）
enum Notifier {
    static func requestPermission(_ done: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            done?(granted)
        }
    }

    static func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

/// 外置硬盘操作：推出、卸载、挂载（调用系统自带的 diskutil，不需要管理员权限）
enum DiskAction: String {
    case eject = "eject"
    case unmount = "unmountDisk"
    case mount = "mountDisk"

    /// 在后台执行，完成后回到主线程回调（成功与否、diskutil 的输出）
    func run(_ bsdName: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            p.arguments = [rawValue, bsdName]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            var ok = false
            var output = ""
            do {
                try p.run()
                output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                p.waitUntilExit()
                ok = p.terminationStatus == 0
            } catch {
                output = error.localizedDescription
            }
            DispatchQueue.main.async { completion(ok, output.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }
}
