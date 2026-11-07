import Foundation
import IOKit

/// 一个已挂载卷的空间信息
struct VolumeInfo {
    let name: String
    let total: Int64
    let free: Int64
    var used: Int64 { max(total - free, 0) }
}

enum Volumes {
    /// 卷的 BSD 名（如 disk3s1s1）→ 所在物理硬盘（如 disk0）
    private static var cache: [String: String] = [:]

    static func resetCache() { cache = [:] }

    /// 按物理硬盘分组的可见卷
    static func byDisk() -> [String: [VolumeInfo]] {
        let keys: [URLResourceKey] = [
            .volumeLocalizedNameKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else { return [:] }

        var out: [String: [VolumeInfo]] = [:]
        for url in urls {
            var st = statfs()
            guard statfs(url.path, &st) == 0 else { continue }
            let from = withUnsafeBytes(of: st.f_mntfromname) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            guard from.hasPrefix("/dev/"), let disk = physicalDisk(of: String(from.dropFirst(5))) else { continue }
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let total = v.volumeTotalCapacity, total > 0 else { continue }
            // “重要用途可用空间”包含可清除空间，和访达显示一致；拿不到时退回普通可用空间
            var free = v.volumeAvailableCapacityForImportantUsage ?? 0
            if free <= 0 { free = Int64(v.volumeAvailableCapacity ?? 0) }
            out[disk, default: []].append(VolumeInfo(
                name: v.volumeLocalizedName ?? url.lastPathComponent, total: Int64(total), free: free))
        }
        return out
    }

    /// 沿 IORegistry 往上找，直到遇到物理硬盘的 IOBlockStorageDriver（APFS 卷也能找到真实硬盘）
    private static func physicalDisk(of bsd: String) -> String? {
        if let hit = cache[bsd] { return hit }
        var entry = IOServiceGetMatchingService(0, IOBSDNameMatching(0, 0, bsd))
        guard entry != 0 else { return nil }
        var result: String?
        while true {
            var parent: io_registry_entry_t = 0
            let kr = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            IOObjectRelease(entry)
            guard kr == KERN_SUCCESS else { break }
            entry = parent
            if IOObjectConformsTo(entry, "IOBlockStorageDriver") != 0 {
                result = IORegistryEntrySearchCFProperty(
                    entry, kIOServicePlane, "BSD Name" as CFString, kCFAllocatorDefault,
                    IOOptionBits(kIORegistryIterateRecursively)) as? String
                IOObjectRelease(entry)
                break
            }
        }
        if let result { cache[bsd] = result }
        return result
    }
}
