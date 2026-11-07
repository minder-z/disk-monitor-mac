import Foundation

/// 从 smartctl 读到的温度和健康信息
struct SmartInfo {
    var temperature: Int?
    var passed: Bool?
    var percentUsed: Int?
    var bytesWritten: Double?
    var powerOnHours: Int?
    var unsafeShutdowns: Int?
}

enum Smart {
    /// 优先用应用内置的 smartctl，找不到时再用用户自己安装的
    static let path: String? = {
        var candidates: [String] = []
        if let bundled = Bundle.main.path(forAuxiliaryExecutable: "smartctl") { candidates.append(bundled) }
        candidates += [
            "/opt/homebrew/bin/smartctl", "/opt/homebrew/sbin/smartctl",
            "/usr/local/bin/smartctl", "/usr/local/sbin/smartctl",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    /// 调用 smartctl 的 JSON 输出；读取失败（如硬盘盒不支持透传）时返回 nil
    static func read(_ bsdName: String) -> SmartInfo? {
        guard let path else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["-j", "-H", "-A", "/dev/\(bsdName)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        guard let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var s = SmartInfo()
        s.temperature = ((j["temperature"] as? [String: Any])?["current"] as? NSNumber)?.intValue
        s.passed = (j["smart_status"] as? [String: Any])?["passed"] as? Bool
        s.powerOnHours = ((j["power_on_time"] as? [String: Any])?["hours"] as? NSNumber)?.intValue

        if let n = j["nvme_smart_health_information_log"] as? [String: Any] {
            s.percentUsed = (n["percentage_used"] as? NSNumber)?.intValue
            if let units = (n["data_units_written"] as? NSNumber)?.doubleValue {
                s.bytesWritten = units * 512_000  // NVMe 每个 data unit = 1000 × 512 字节
            }
            s.unsafeShutdowns = (n["unsafe_shutdowns"] as? NSNumber)?.intValue
            if s.temperature == nil { s.temperature = (n["temperature"] as? NSNumber)?.intValue }
        }

        if s.temperature == nil && s.passed == nil && s.percentUsed == nil { return nil }
        return s
    }
}
