import Foundation

/// 网络流量（只统计 en* 网卡：Wi-Fi、有线、USB/雷雳网卡、iPhone 共享网络；
/// VPN 隧道 utun 的流量也会经过 en*，计入会重复统计）
enum NetIO {
    struct Totals {
        var received: UInt64 = 0
        var sent: UInt64 = 0
    }

    /// 计算速度用的计数器（每秒读一次，开销很小）。
    /// 注意：macOS 给普通应用的计数会在 4 GB 处回绕，所以只能用来算差值，见 delta(_:_:)。
    static func counters() -> Totals {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else { return Totals() }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return Totals() }

        var t = Totals()
        buf.withUnsafeBytes { raw in
            var offset = 0
            let headerSize = MemoryLayout<if_msghdr>.size
            while offset + headerSize <= len {
                let hdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let msgLen = Int(hdr.ifm_msglen)
                if msgLen <= 0 { break }
                if Int32(hdr.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= len {
                    let h2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if h2.ifm_flags & IFF_LOOPBACK == 0, isCounted(index: h2.ifm_index) {
                        // 按 32 位累加，和系统计数的回绕方式一致
                        t.received = UInt64(UInt32(truncatingIfNeeded: t.received) &+ UInt32(truncatingIfNeeded: h2.ifm_data.ifi_ibytes))
                        t.sent = UInt64(UInt32(truncatingIfNeeded: t.sent) &+ UInt32(truncatingIfNeeded: h2.ifm_data.ifi_obytes))
                    }
                }
                offset += msgLen
            }
        }
        return t
    }

    /// 两次计数之间的字节数，正确处理 4 GB 回绕（每秒流量不会超过 4 GB）
    static func delta(_ new: UInt64, _ old: UInt64) -> UInt64 {
        UInt64(UInt32(truncatingIfNeeded: new) &- UInt32(truncatingIfNeeded: old))
    }

    /// 准确的累计流量：调用系统自带的 netstat（它能读到完整的 64 位计数），只在菜单打开时用
    static func cumulative() -> Totals {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        p.arguments = ["-ibn"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return Totals() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        var t = Totals()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let f = line.split(separator: " ", omittingEmptySubsequences: true)
            // 每块网卡只取 <Link#n> 那一行；末尾 7 列依次是 Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
            guard f.count >= 8, f[0].hasPrefix("en"), f[2].hasPrefix("<Link") else { continue }
            t.received &+= UInt64(f[f.count - 5]) ?? 0
            t.sent &+= UInt64(f[f.count - 2]) ?? 0
        }
        return t
    }

    private static func isCounted(index: UInt16) -> Bool {
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &name) != nil else { return false }
        return String(cString: name).hasPrefix("en")
    }
}
