import Foundation
import IOKit

/// 一块物理硬盘在某一时刻的累计读写字节数
struct DiskSample {
    let bsdName: String      // 例如 disk0
    let model: String        // 例如 APPLE SSD AP0256Z
    let isExternal: Bool
    let interconnect: String // 例如 Apple Fabric、USB、PCI-Express
    let bytesRead: UInt64
    let bytesWritten: UInt64
}

/// 通过 IOKit 读取每块硬盘驱动的 Statistics，不需要管理员权限
enum DiskIO {
    static func snapshot() -> [DiskSample] {
        var iter: io_iterator_t = 0
        // 主端口传 0（默认端口），兼容 macOS 12 以前的系统
        guard IOServiceGetMatchingServices(0,
                                           IOServiceMatching("IOBlockStorageDriver"),
                                           &iter) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iter) }

        var out: [DiskSample] = []
        while true {
            let driver = IOIteratorNext(iter)
            if driver == 0 { break }
            defer { IOObjectRelease(driver) }

            guard let stats = property(driver, "Statistics") as? [String: Any],
                  let bsd = IORegistryEntrySearchCFProperty(
                      driver, kIOServicePlane, "BSD Name" as CFString, kCFAllocatorDefault,
                      IOOptionBits(kIORegistryIterateRecursively)) as? String
            else { continue }

            let read = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            let written = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0

            var model = bsd
            var external = false
            var interconnect = ""
            var parent: io_registry_entry_t = 0
            if IORegistryEntryGetParentEntry(driver, kIOServicePlane, &parent) == KERN_SUCCESS {
                defer { IOObjectRelease(parent) }
                if let dc = property(parent, "Device Characteristics") as? [String: Any] {
                    let vendor = (dc["Vendor Name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                    let product = (dc["Product Name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                    let name = [vendor, product].filter { !$0.isEmpty }.joined(separator: " ")
                    if !name.isEmpty { model = name }
                }
                if let pc = property(parent, "Protocol Characteristics") as? [String: Any] {
                    interconnect = pc["Physical Interconnect"] as? String ?? ""
                    external = (pc["Physical Interconnect Location"] as? String) == "External"
                }
            }
            // 跳过磁盘映像等虚拟盘
            if interconnect == "Virtual Interface" || (property(driver, "Physical Interconnect") as? String) == "Virtual Interface" {
                continue
            }

            out.append(DiskSample(bsdName: bsd, model: model, isExternal: external,
                                  interconnect: interconnect, bytesRead: read, bytesWritten: written))
        }
        // 内置盘在前，外置盘在后
        return out.sorted {
            if $0.isExternal != $1.isExternal { return !$0.isExternal }
            return $0.bsdName.localizedStandardCompare($1.bsdName) == .orderedAscending
        }
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
