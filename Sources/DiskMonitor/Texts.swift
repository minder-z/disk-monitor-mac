import Foundation

/// 应用内语言选择：nil 表示跟随系统
enum Lang {
    /// (语言代码, 该语言自己的名称)
    static let supported: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"),
        ("ko", "한국어"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español"),
    ]

    private static let key = "appLanguage"

    static var selected: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
            bundle = makeBundle()
        }
    }

    /// 当前用来取翻译的语言包；切换后立即生效，不用重启
    private(set) static var bundle: Bundle = makeBundle()

    private static func makeBundle() -> Bundle {
        if let code = selected,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let b = Bundle(path: path) { return b }
        return Bundle.main
    }
}

/// 取本地化文字（键就是英文原文，找不到翻译时直接显示英文）
func L(_ key: String) -> String { Lang.bundle.localizedString(forKey: key, value: key, table: nil) }

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: args)
}

/// 菜单里的一行：普通文字，或带用量条的卷信息
enum Row {
    case text(String)
    case volume(fraction: Double, text: String)

    /// 调试输出用的纯文字形式
    var plain: String {
        switch self {
        case .text(let s): return s
        case .volume(let f, let s): return Texts.usageBar(f) + " " + s
        }
    }

    var isVolume: Bool { if case .volume = self { return true } else { return false } }
}

/// 菜单和调试输出共用的文字
enum Texts {
    static func label(isExternal: Bool, index: Int?, short: Bool) -> String {
        let base = short ? L(isExternal ? "Ext" : "Int") : L(isExternal ? "External" : "Internal")
        guard let index else { return base }
        return base + "\(index)"
    }

    static func usageBar(_ fraction: Double, width: Int = 10) -> String {
        let n = min(max(Int((fraction * Double(width)).rounded()), 0), width)
        return String(repeating: "#", count: n) + String(repeating: "-", count: width - n)
    }

    static func detailRows(read: Double, write: Double, smart s: SmartInfo?,
                           smartUnavailable: Bool, volumes: [VolumeInfo]) -> [Row] {
        let temp = s?.temperature.map { "\($0)°C" } ?? "--"
        let health = s?.passed.map { L($0 ? "Good" : "Failing!") } ?? "--"
        var rows: [Row] = [
            .text(LF("Temperature %@      Health %@", temp, health)),
            .text(LF("Read %@      Write %@", Fmt.speedLong(read), Fmt.speedLong(write))),
        ]
        var extra: [String] = []
        if let p = s?.percentUsed { extra.append(LF("Life used %@", "\(p)%")) }
        if let b = s?.bytesWritten { extra.append(LF("Total written %@", Fmt.size(b))) }
        if !extra.isEmpty { rows.append(.text(extra.joined(separator: "      "))) }
        if let h = s?.powerOnHours, let u = s?.unsafeShutdowns {
            rows.append(.text(LF("Powered on %@ h      Unsafe shutdowns %@", "\(h)", "\(u)")))
        }
        if s == nil && smartUnavailable {
            rows.append(.text(L("No temperature or health data (enclosure may not support it)")))
        }
        for v in volumes {
            let fraction = v.total > 0 ? Double(v.used) / Double(v.total) : 0
            let pct = Int((fraction * 100).rounded())
            rows.append(.volume(fraction: fraction, text: "\(pct)%  "
                + LF("%@: %@ used of %@ · %@ free", v.name,
                     Fmt.size(Double(v.used)), Fmt.size(Double(v.total)), Fmt.size(Double(v.free)))))
        }
        return rows
    }
}
