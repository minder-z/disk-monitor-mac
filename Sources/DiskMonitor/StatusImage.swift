import AppKit

enum Fmt {
    /// 状态栏用的短格式，例如 512K、12.3M、1.20G
    static func speedShort(_ bps: Double) -> String {
        let k = bps / 1024
        if k < 1 { return "0K" }
        if k < 1000 { return String(format: "%.0fK", k) }
        let m = k / 1024
        if m < 100 { return String(format: "%.1fM", m) }
        if m < 1000 { return String(format: "%.0fM", m) }
        return String(format: "%.2fG", m / 1024)
    }

    /// 菜单里用的完整格式
    static func speedLong(_ bps: Double) -> String {
        let k = bps / 1024
        if k < 1000 { return String(format: "%.0f KB/s", k) }
        let m = k / 1024
        if m < 1000 { return String(format: "%.1f MB/s", m) }
        return String(format: "%.2f GB/s", m / 1024)
    }

    /// 容量（十进制，和 smartctl 一致）
    static func size(_ bytes: Double) -> String {
        if bytes >= 1e12 { return String(format: "%.2f TB", bytes / 1e12) }
        if bytes >= 1e9 { return String(format: "%.0f GB", bytes / 1e9) }
        return String(format: "%.0f MB", bytes / 1e6)
    }
}

/// 把每块硬盘画成两行小字：左边温度/名称，右边写入/读取速度
enum StatusImage {
    struct Block {
        let label: String
        let temp: Int?
        let read: Double
        let write: Double
    }

    static func make(_ blocks: [Block]) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        func width(_ s: String) -> CGFloat { ceil((s as NSString).size(withAttributes: attrs).width) }

        let writePrefix = L("W")
        let readPrefix = L("R")
        let prefixW = max(width(writePrefix + " "), width(readPrefix + " "))
        let numberW = width("888.8M")
        let speedW = prefixW + numberW
        let innerGap: CGFloat = 4
        let blockGap: CGFloat = 10
        let height: CGFloat = 22

        struct Laid { let top: String; let bottom: String; let leftW: CGFloat; let read: String; let write: String }
        let laid = blocks.map { b -> Laid in
            let top = b.temp.map { "\($0)°" } ?? "--°"
            return Laid(top: top, bottom: b.label, leftW: max(width(top), width(b.label)),
                        read: Fmt.speedShort(b.read), write: Fmt.speedShort(b.write))
        }
        let total = laid.reduce(0) { $0 + $1.leftW + innerGap + speedW } + blockGap * CGFloat(max(laid.count - 1, 0))

        let image = NSImage(size: NSSize(width: max(total, 1), height: height), flipped: false) { _ in
            let topY: CGFloat = 10.5
            let bottomY: CGFloat = 0.5
            var x: CGFloat = 0
            for l in laid {
                (l.top as NSString).draw(at: NSPoint(x: x, y: topY), withAttributes: attrs)
                (l.bottom as NSString).draw(at: NSPoint(x: x, y: bottomY), withAttributes: attrs)
                x += l.leftW + innerGap

                (writePrefix as NSString).draw(at: NSPoint(x: x, y: topY), withAttributes: attrs)
                (readPrefix as NSString).draw(at: NSPoint(x: x, y: bottomY), withAttributes: attrs)
                let right = x + speedW
                (l.write as NSString).draw(at: NSPoint(x: right - width(l.write), y: topY), withAttributes: attrs)
                (l.read as NSString).draw(at: NSPoint(x: right - width(l.read), y: bottomY), withAttributes: attrs)
                x = right + blockGap
            }
            return true
        }
        image.isTemplate = true  // 自动适配浅色/深色菜单栏
        return image
    }
}
