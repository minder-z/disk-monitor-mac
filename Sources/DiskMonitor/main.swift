import AppKit

// 调试用：DiskMonitor --dump [图片路径.png] [-AppleLanguages '(ja)']
// 在终端打印 2 秒内的读写速度、SMART 和空间信息（与菜单文字相同）后退出；
// 给出图片路径时，额外导出状态栏图像（放大 4 倍、白底）用于检查排版
if let dumpIndex = CommandLine.arguments.firstIndex(of: "--dump") {
    let a = DiskIO.snapshot()
    Thread.sleep(forTimeInterval: 2)
    let b = DiskIO.snapshot()
    let volumes = Volumes.byDisk()
    print("smartctl: \(Smart.path ?? "-")")
    for s in b {
        let p = a.first { $0.bsdName == s.bsdName }
        let r = Double(s.bytesRead - (p?.bytesRead ?? s.bytesRead)) / 2
        let w = Double(s.bytesWritten - (p?.bytesWritten ?? s.bytesWritten)) / 2
        let label = Texts.label(isExternal: s.isExternal, index: nil, short: false)
        print("\(label) · \(s.model)  (\(s.bsdName), \(s.interconnect))")
        let rows = Texts.detailRows(read: r, write: w, smart: Smart.read(s.bsdName),
                                    smartUnavailable: true, volumes: volumes[s.bsdName] ?? [])
        rows.forEach { print("    " + $0.plain) }
    }

    let next = dumpIndex + 1
    if next < CommandLine.arguments.count, !CommandLine.arguments[next].hasPrefix("-") {
        let blocks = [
            StatusImage.Block(label: Texts.label(isExternal: false, index: nil, short: true), temp: 38, read: 25.6e6, write: 2.4e6),
            StatusImage.Block(label: Texts.label(isExternal: true, index: nil, short: true), temp: 42, read: 22e3, write: 544e6),
        ]
        let img = StatusImage.make(blocks)
        let scale: CGFloat = 4
        let size = NSSize(width: img.size.width * scale, height: img.size.height * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[next]))
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // 只在状态栏显示，不出现在 Dock
app.run()
