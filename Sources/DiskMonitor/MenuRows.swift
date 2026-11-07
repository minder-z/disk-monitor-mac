import AppKit

/// 圆角用量条：正常为系统强调色，超过 80% 橙色，超过 90% 红色
final class UsageBarView: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds
        let radius = r.height / 2
        NSColor.tertiaryLabelColor.setFill()
        NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()

        let f = CGFloat(min(max(fraction, 0), 1))
        guard f > 0 else { return }
        let color: NSColor = f >= 0.9 ? .systemRed : (f >= 0.8 ? .systemOrange : .controlAccentColor)
        color.setFill()
        let filled = NSRect(x: r.minX, y: r.minY, width: max(r.height, r.width * f), height: r.height)
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }
}

/// 菜单里的一行信息。用自定义视图，文字才能是正常颜色（系统会把不可点的菜单项强制变灰）
final class InfoRowView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var bar: UsageBarView?
    private let leading: CGFloat
    private(set) var isVolume: Bool

    private static let rowHeight: CGFloat = 20
    private static let barWidth: CGFloat = 80
    private static let barHeight: CGFloat = 6

    init(row: Row, leading: CGFloat, bold: Bool = false) {
        self.leading = leading
        self.isVolume = row.isVolume
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: Self.rowHeight))
        label.font = bold ? .boldSystemFont(ofSize: 13) : .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = bold ? .labelColor : .labelColor
        label.lineBreakMode = .byClipping
        addSubview(label)
        if isVolume {
            let b = UsageBarView()
            addSubview(b)
            bar = b
        }
        autoresizingMask = [.width]
        update(row)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ row: Row) {
        switch row {
        case .text(let s):
            label.stringValue = s
        case .volume(let f, let s):
            label.stringValue = s
            bar?.fraction = f
        }
        label.sizeToFit()
        var x = leading
        if let bar {
            bar.frame = NSRect(x: x, y: (Self.rowHeight - Self.barHeight) / 2,
                               width: Self.barWidth, height: Self.barHeight)
            x += Self.barWidth + 8
        }
        label.frame.origin = NSPoint(x: x, y: (Self.rowHeight - label.frame.height) / 2)
        // 只会变宽不会变窄，避免菜单打开时宽度来回跳
        let needed = ceil(x + label.frame.width + 20)
        setFrameSize(NSSize(width: max(frame.width, needed), height: Self.rowHeight))
    }
}
