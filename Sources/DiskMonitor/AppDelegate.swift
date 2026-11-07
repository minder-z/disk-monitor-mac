import AppKit
import UserNotifications

struct DiskState {
    let sample: DiskSample
    var readBps: Double
    var writeBps: Double
    /// 用型号+内外置作为偏好设置的键，重新插拔后 diskN 编号变化也能记住
    var key: String { sample.model + (sample.isExternal ? "|ext" : "|int") }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?

    private var prev: [String: (r: UInt64, w: UInt64, t: TimeInterval)] = [:]
    private var disks: [DiskState] = []
    private var knownDiskNames: [String] = []
    private var smart: [String: SmartInfo] = [:]
    private var smartAttempted: Set<String> = []
    private var lastSmartPoll: TimeInterval = 0
    private var smartBusy = false
    private let smartQueue = DispatchQueue(label: "smart", qos: .utility)
    private let smartInterval: TimeInterval = 20

    private var volumes: [String: [VolumeInfo]] = [:]
    private var menuIsOpen = false
    private var liveItems: [String: [InfoRowView]] = [:]

    /// 温度达到这个值就提醒，降到它减 5 度以下才会再次提醒
    private let tempAlertThreshold = 70
    private var activeAlerts: Set<String> = []

    private var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "alertsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "alertsEnabled") }
    }

    private var hiddenKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "hiddenDisks") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "hiddenDisks") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)  // 菜单打开时也继续刷新
        timer = t

        UNUserNotificationCenter.current().delegate = self
        Notifier.requestPermission { granted in
            // 调试用：open DiskMonitor.app --args --test-alert 发一条测试通知
            if granted && CommandLine.arguments.contains("--test-alert") {
                Notifier.send(id: "test", title: L("Disk temperature is high"),
                              body: LF("%@ is at %@.", "Test Disk", "\(self.tempAlertThreshold)°C"))
            }
        }
    }

    /// 应用在前台时也显示通知横幅
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    // MARK: - 数据刷新

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let samples = DiskIO.snapshot()
        var next: [String: (r: UInt64, w: UInt64, t: TimeInterval)] = [:]
        disks = samples.map { s in
            var r = 0.0, w = 0.0
            if let p = prev[s.bsdName], now > p.t {
                let dt = now - p.t
                if s.bytesRead >= p.r { r = Double(s.bytesRead - p.r) / dt }
                if s.bytesWritten >= p.w { w = Double(s.bytesWritten - p.w) / dt }
            }
            next[s.bsdName] = (r: s.bytesRead, w: s.bytesWritten, t: now)
            return DiskState(sample: s, readBps: r, writeBps: w)
        }
        prev = next

        // 插拔硬盘后 diskN 编号可能变化，清掉旧的对应关系
        let names = samples.map { $0.bsdName }
        if names != knownDiskNames {
            knownDiskNames = names
            Volumes.resetCache()
            smartAttempted.formIntersection(names)
        }

        let hasNewDisk = disks.contains { !smartAttempted.contains($0.sample.bsdName) }
        if !smartBusy && (hasNewDisk || now - lastSmartPoll >= smartInterval) { pollSmart() }

        render()
        if menuIsOpen { refreshLiveItems() }
    }

    private func pollSmart() {
        smartBusy = true
        lastSmartPoll = ProcessInfo.processInfo.systemUptime
        let names = disks.map { $0.sample.bsdName }
        smartAttempted.formUnion(names)
        smartQueue.async { [weak self] in
            var result: [String: SmartInfo] = [:]
            for n in names { if let s = Smart.read(n) { result[n] = s } }
            DispatchQueue.main.async {
                guard let self else { return }
                self.smart = result
                self.smartBusy = false
                self.checkAlerts()
                self.render()
                if self.menuIsOpen { self.refreshLiveItems() }
            }
        }
    }

    // MARK: - 提醒

    private func checkAlerts() {
        guard alertsEnabled else { return }
        for d in disks {
            guard let s = smart[d.sample.bsdName] else { continue }
            let name = "\(label(d, short: false)) · \(d.sample.model)"
            if let t = s.temperature {
                if t >= tempAlertThreshold {
                    raiseAlert(d, "temp", L("Disk temperature is high"), LF("%@ is at %@.", name, "\(t)°C"))
                } else if t <= tempAlertThreshold - 5 {
                    activeAlerts.remove(d.key + "|temp")
                }
            }
            if s.passed == false {
                raiseAlert(d, "health", L("Disk health problem"),
                           LF("%@ failed its SMART health check. Back up your data now.", name))
            }
            if let p = s.percentUsed, p >= 90 {
                raiseAlert(d, "life", L("Disk nearing end of life"), LF("%@ has used %@ of its rated life.", name, "\(p)%"))
            }
        }
    }

    /// 同一块盘的同一种问题只提醒一次，直到问题消失
    private func raiseAlert(_ d: DiskState, _ kind: String, _ title: String, _ body: String) {
        let id = d.key + "|" + kind
        guard !activeAlerts.contains(id) else { return }
        activeAlerts.insert(id)
        Notifier.send(id: id, title: title, body: body)
    }

    // MARK: - 状态栏

    private func label(_ d: DiskState, short: Bool) -> String {
        let group = disks.filter { $0.sample.isExternal == d.sample.isExternal }
        var index: Int?
        if group.count > 1, let i = group.firstIndex(where: { $0.sample.bsdName == d.sample.bsdName }) {
            index = i + 1
        }
        return Texts.label(isExternal: d.sample.isExternal, index: index, short: short)
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let hidden = hiddenKeys
        let shown = disks.filter { !hidden.contains($0.key) }
        if shown.isEmpty {
            button.image = nil
            button.title = L("Disk")
            return
        }
        button.title = ""
        button.image = StatusImage.make(shown.map { d in
            StatusImage.Block(label: label(d, short: true), temp: smart[d.sample.bsdName]?.temperature,
                              read: d.readBps, write: d.writeBps)
        })
    }

    // MARK: - 菜单

    func menuNeedsUpdate(_ menu: NSMenu) { buildMenu() }
    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    // 自定义视图的左边距：标题和普通菜单项文字对齐，详细信息再缩进一级
    private let headerLeading: CGFloat = 21
    private let detailLeading: CGFloat = 33

    private func infoItem(_ row: Row, leading: CGFloat, bold: Bool = false) -> (NSMenuItem, InfoRowView) {
        let view = InfoRowView(row: row, leading: leading, bold: bold)
        let item = NSMenuItem()
        item.view = view
        return (item, view)
    }

    private func detailRows(_ d: DiskState) -> [Row] {
        let bsd = d.sample.bsdName
        return Texts.detailRows(read: d.readBps, write: d.writeBps, smart: smart[bsd],
                                smartUnavailable: smartAttempted.contains(bsd) && !smartBusy,
                                volumes: volumes[bsd] ?? [])
    }

    private func buildMenu() {
        menu.removeAllItems()
        liveItems = [:]
        volumes = Volumes.byDisk()
        let hidden = hiddenKeys

        if disks.isEmpty {
            menu.addItem(infoItem(.text(L("No disks detected")), leading: headerLeading).0)
            menu.addItem(.separator())
        }

        for d in disks {
            let title = "\(label(d, short: false)) · \(d.sample.model)  (\(d.sample.bsdName))"
            menu.addItem(infoItem(.text(title), leading: headerLeading, bold: true).0)
            var views: [InfoRowView] = []
            for row in detailRows(d) {
                let (item, view) = infoItem(row, leading: detailLeading)
                menu.addItem(item)
                views.append(view)
            }
            liveItems[d.sample.bsdName] = views

            let toggle = NSMenuItem(title: L("Show in menu bar"), action: #selector(toggleDisk(_:)), keyEquivalent: "")
            toggle.target = self
            toggle.representedObject = d.key
            toggle.state = hidden.contains(d.key) ? .off : .on
            toggle.indentationLevel = 1
            menu.addItem(toggle)

            // 外置硬盘：推出 / 卸载 / 挂载
            if d.sample.isExternal {
                let name = "\(label(d, short: false)) · \(d.sample.model)"
                let mounted = !(volumes[d.sample.bsdName] ?? []).isEmpty
                menu.addItem(actionItem("⏏ " + L("Eject"), .eject, d, name))
                menu.addItem(mounted ? actionItem(L("Unmount"), .unmount, d, name)
                                     : actionItem(L("Mount"), .mount, d, name))
            }
            menu.addItem(.separator())
        }

        if Smart.path == nil {
            menu.addItem(infoItem(.text(L("smartctl not found, temperature unavailable")), leading: headerLeading).0)
            menu.addItem(infoItem(.text(L("Install it with: brew install smartmontools")), leading: headerLeading).0)
            menu.addItem(.separator())
        }

        let login = NSMenuItem(title: L("Launch at login"), action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let alerts = NSMenuItem(title: L("Temperature and health alerts"), action: #selector(toggleAlerts(_:)), keyEquivalent: "")
        alerts.target = self
        alerts.state = alertsEnabled ? .on : .off
        menu.addItem(alerts)

        // 语言选择
        let langMenu = NSMenu()
        let follow = NSMenuItem(title: L("Follow System"), action: #selector(chooseLanguage(_:)), keyEquivalent: "")
        follow.target = self
        follow.state = Lang.selected == nil ? .on : .off
        langMenu.addItem(follow)
        langMenu.addItem(.separator())
        for (code, name) in Lang.supported {
            let item = NSMenuItem(title: name, action: #selector(chooseLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            item.state = Lang.selected == code ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "\u{1F310} " + L("Language"), action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let about = NSMenuItem(title: L("About Disk Monitor"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func refreshLiveItems() {
        volumes = Volumes.byDisk()
        for d in disks {
            guard let views = liveItems[d.sample.bsdName] else { continue }
            let rows = detailRows(d)
            // 行数或类型变了（比如 SMART 刚读到）就等下次打开菜单再重建
            guard rows.count == views.count,
                  zip(rows, views).allSatisfy({ $0.isVolume == $1.isVolume }) else { continue }
            for (view, row) in zip(views, rows) { view.update(row) }
        }
    }

    private func actionItem(_ title: String, _ action: DiskAction, _ d: DiskState, _ name: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(runDiskAction(_:)), keyEquivalent: "")
        item.target = self
        item.indentationLevel = 1
        item.representedObject = [action.rawValue, d.sample.bsdName, name]
        return item
    }

    @objc private func runDiskAction(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String], info.count == 3,
              let action = DiskAction(rawValue: info[0]) else { return }
        let name = info[2]
        action.run(info[1]) { [weak self] ok, output in
            guard let self else { return }
            if ok {
                if action == .eject {
                    Notifier.send(id: "eject|" + info[1], title: L("Safe to disconnect"), body: LF("%@ has been ejected.", name))
                }
                self.tick()
            } else {
                self.showError(L("Couldn't complete the operation"), "\(name)\n\n\(output)")
            }
        }
    }

    private func showError(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleAlerts(_ sender: NSMenuItem) {
        alertsEnabled.toggle()
        activeAlerts.removeAll()
        if alertsEnabled { checkAlerts() }
    }

    @objc private func showAbout() {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor, .paragraphStyle: para,
        ]
        let credits = NSMutableAttributedString()
        func text(_ s: String) { credits.append(NSAttributedString(string: s, attributes: base)) }
        func link(_ s: String, _ url: URL) {
            var a = base
            a[.link] = url
            credits.append(NSAttributedString(string: s, attributes: a))
        }
        text(L("Shows disk temperature, health, read/write speed and free space in the menu bar.") + "\n\n")
        link("github.com/minder-z/disk-monitor-mac", URL(string: "https://github.com/minder-z/disk-monitor-mac")!)
        text("\n\n" + L("Includes smartctl from smartmontools 7.5, licensed under the GNU GPL v2. Source code:") + "\n")
        link("smartmontools-7.5.tar.gz",
             URL(string: "https://github.com/smartmontools/smartmontools/releases/tag/RELEASE_7_5")!)
        if let license = Bundle.main.url(forResource: "COPYING", withExtension: "txt",
                                         subdirectory: "Licenses/smartmontools") {
            text("  ·  ")
            link(L("View License"), license)
        }
        let name = Lang.bundle.localizedString(forKey: "CFBundleDisplayName", value: "Disk Monitor", table: "InfoPlist")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationName: name])
    }

    @objc private func toggleDisk(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        var hidden = hiddenKeys
        if hidden.contains(key) { hidden.remove(key) } else { hidden.insert(key) }
        hiddenKeys = hidden
        render()
    }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        Lang.selected = sender.representedObject as? String
        render()  // 状态栏立即换成新语言；菜单下次打开时重建
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            showError(L("Couldn't change launch at login"),
                      "\(error.localizedDescription)\n\n" + L("Try moving the app to the Applications folder first."))
        }
    }
}
