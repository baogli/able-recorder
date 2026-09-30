import AppKit
import AVFoundation
import ScreenCaptureKit
import UniformTypeIdentifiers
import Carbon

enum PrivacyPane {
    case screen, microphone
    var url: URL {
        let anchor = self == .screen ? "Privacy_ScreenCapture" : "Privacy_Microphone"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?" + anchor)!
    }
}

struct PrivacyAccessError: LocalizedError {
    let pane: PrivacyPane
    var errorDescription: String? {
        pane == .screen
            ? "Разреши Able Recorder запись экрана в настройках macOS. Если система попросит, перезапусти приложение после изменения доступа."
            : "Разреши «Микрофон» для Able Recorder в настройках macOS. Это разрешение нужно для выбранных loopback-входов аудиокарты."
    }
}

final class MeterView: NSView {
    var left: Float = 0, right: Float = 0
    override var intrinsicContentSize: NSSize { NSSize(width: 480, height: 42) }
    func set(_ l: Float, _ r: Float) { left = l; right = r; needsDisplay = true }
    override func draw(_ rect: NSRect) {
        for (i, peak) in [left, right].enumerated() {
            let y = CGFloat(1 - i) * 21 + 5
            let db = 20 * log10(max(peak, 0.000001))
            let level = CGFloat(max(0, min(1, (db + 60) / 60)))
            let track = NSRect(x: 24, y: y, width: max(0, bounds.width - 100), height: 10)
            NSColor.white.withAlphaComponent(0.08).setFill(); NSBezierPath(roundedRect: track, xRadius: 5, yRadius: 5).fill()
            (peak >= 0.99 ? NSColor.systemRed : peak > 0.7 ? .systemYellow : .systemGreen).setFill()
            NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: track.width * level, height: track.height), xRadius: 5, yRadius: 5).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor]
            (i == 0 ? "L" : "R").draw(at: NSPoint(x: 0, y: y - 1), withAttributes: attrs)
            (peak < 0.00001 ? "−∞ dB" : String(format: "%.0f dB", db)).draw(at: NSPoint(x: bounds.width - 65, y: y - 1), withAttributes: attrs)
        }
    }
}

@MainActor final class RecorderApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let displayPopup = NSPopUpButton(), devicePopup = NSPopUpButton()
    let leftPopup = NSPopUpButton(), rightPopup = NSPopUpButton()
    let resolutionPopup = NSPopUpButton(), fpsPopup = NSPopUpButton(), qualityPopup = NSPopUpButton(), codecPopup = NSPopUpButton()
    let status = NSTextField(wrappingLabelWithString: "Готов к записи"), audioHint = NSTextField(wrappingLabelWithString: "")
    let spec = NSTextField(wrappingLabelWithString: ""), folderLabel = NSTextField(labelWithString: "")
    let permissionStatus = NSTextField(labelWithString: "Проверяю доступ…")
    var screenSettingsButton: NSButton!, audioSettingsButton: NSButton!
    let meter = MeterView()
    let mainButton = NSButton(title: "Начать запись", target: nil, action: nil)
    let monitorButton = NSButton(title: "Проверить звук", target: nil, action: nil)
    let cursorButton = NSButton(checkboxWithTitle: "Показывать курсор", target: nil, action: nil)
    let countdownButton = NSButton(checkboxWithTitle: "Отсчёт 3 секунды", target: nil, action: nil)
    var refreshButton: NSButton!, folderButton: NSButton!, revealButton: NSButton!
    var inputs: [InputDevice] = []
    var displays: [CGDirectDisplayID] = []
    var session: RecordingSession?
    var mode = "idle"
    var startDate: Date?, lastSignal = Date.distantPast, lastFile: URL?, pendingFile: URL?
    var pendingError: String?, videoDrops = 0, audioDrops = 0, ringDrops: UInt64 = 0
    var tick: Timer?, statusItem: NSStatusItem!, hotkey: EventHotKeyRef?
    var folder: URL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!.appendingPathComponent("Able Recorder", isDirectory: true)
    var controls: [NSControl] = []
    let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if let saved = defaults.string(forKey: "folder") { folder = URL(fileURLWithPath: saved, isDirectory: true) }
        buildWindow(); buildMenu(); refreshDevices(); updateFolder(); updatePermissionStatus()
        tick = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateTick() } }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSTextField {
        let v = NSTextField(wrappingLabelWithString: text); v.font = .systemFont(ofSize: size, weight: weight); return v
    }
    func row(_ title: String, _ views: NSView...) -> NSStackView {
        let name = label(title, weight: .medium); name.widthAnchor.constraint(equalToConstant: 95).isActive = true
        let stack = NSStackView(views: [name] + views); stack.orientation = .horizontal; stack.spacing = 12; stack.alignment = .centerY
        return stack
    }
    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 630, height: 710), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Able Recorder"; window.center(); window.delegate = self; window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.085, alpha: 1)
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28), root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28), root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26)])
        let heading = label("Able Recorder", size: 25, weight: .bold)
        root.addArrangedSubview(heading)
        let subtitle = label("Эйбл рекордер · Экран + выбранные аудиовходы → MP4", size: 13); subtitle.textColor = .secondaryLabelColor; root.addArrangedSubview(subtitle)
        root.addArrangedSubview(NSBox.separator())
        screenSettingsButton = NSButton(title: "Доступ к экрану…", target: self, action: #selector(openScreenSettings))
        audioSettingsButton = NSButton(title: "Доступ к аудио…", target: self, action: #selector(openAudioSettings))
        screenSettingsButton.toolTip = "Открыть настройки macOS → Конфиденциальность → Запись экрана и системного аудио"
        audioSettingsButton.toolTip = "Открыть настройки macOS → Конфиденциальность → Микрофон (включая входы аудиокарты)"
        root.addArrangedSubview(row("Разрешения", screenSettingsButton, audioSettingsButton))
        permissionStatus.font = .systemFont(ofSize: 11); permissionStatus.textColor = .secondaryLabelColor
        root.addArrangedSubview(permissionStatus)
        permissionStatus.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        refreshButton = NSButton(title: "↻", target: self, action: #selector(refreshDevices)); refreshButton.toolTip = "Обновить экраны и аудиоустройства"
        for popup in [displayPopup, devicePopup, leftPopup, rightPopup, resolutionPopup, fpsPopup, qualityPopup, codecPopup] { popup.target = self; popup.action = #selector(selectionChanged(_:)); popup.controlSize = .large }
        displayPopup.widthAnchor.constraint(equalToConstant: 410).isActive = true
        devicePopup.widthAnchor.constraint(equalToConstant: 410).isActive = true
        root.addArrangedSubview(row("Экран", displayPopup, refreshButton))
        root.addArrangedSubview(row("Аудиокарта", devicePopup))
        leftPopup.widthAnchor.constraint(equalToConstant: 170).isActive = true; rightPopup.widthAnchor.constraint(equalToConstant: 170).isActive = true
        root.addArrangedSubview(row("Входы", label("L"), leftPopup, label("R"), rightPopup))
        audioHint.font = .systemFont(ofSize: 11); audioHint.textColor = .secondaryLabelColor
        root.addArrangedSubview(audioHint); audioHint.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.addArrangedSubview(meter); meter.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        monitorButton.target = self; monitorButton.action = #selector(toggleMonitor); monitorButton.bezelStyle = .rounded
        root.addArrangedSubview(monitorButton)
        root.addArrangedSubview(NSBox.separator())
        resolutionPopup.addItems(withTitles: ["1080p", "1440p", "2160p / 4K", "Размер экрана"])
        fpsPopup.addItems(withTitles: ["30 fps", "60 fps"])
        qualityPopup.addItems(withTitles: VideoPreset.all.map(\.title)); qualityPopup.selectItem(at: 1)
        codecPopup.addItems(withTitles: ["H.264 · совместимый", "HEVC · компактнее"])
        root.addArrangedSubview(row("Видео", resolutionPopup, fpsPopup, codecPopup))
        root.addArrangedSubview(row("Качество", qualityPopup))
        spec.font = .systemFont(ofSize: 11); spec.textColor = .secondaryLabelColor; root.addArrangedSubview(spec)
        cursorButton.state = .on; countdownButton.state = .on
        root.addArrangedSubview(NSStackView(views: [cursorButton, countdownButton]))
        folderLabel.lineBreakMode = .byTruncatingMiddle; folderLabel.font = .systemFont(ofSize: 11); folderLabel.textColor = .secondaryLabelColor
        folderLabel.widthAnchor.constraint(equalToConstant: 370).isActive = true
        folderButton = NSButton(title: "Изменить…", target: self, action: #selector(chooseFolder))
        root.addArrangedSubview(row("Сохранение", folderLabel, folderButton))
        mainButton.target = self; mainButton.action = #selector(toggleRecording); mainButton.bezelStyle = .rounded; mainButton.controlSize = .large
        mainButton.contentTintColor = .systemRed; mainButton.font = .systemFont(ofSize: 16, weight: .semibold)
        mainButton.widthAnchor.constraint(equalToConstant: 250).isActive = true; mainButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        revealButton = NSButton(title: "Последний MP4 ↗", target: self, action: #selector(revealLast)); revealButton.isEnabled = false
        root.addArrangedSubview(NSStackView(views: [mainButton, revealButton]))
        status.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium); root.addArrangedSubview(status); status.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let shortcut = label("⌃⇧R — начать / остановить • закрытое окно остаётся в строке меню", size: 10); shortcut.textColor = .tertiaryLabelColor; root.addArrangedSubview(shortcut)
        controls = [displayPopup, devicePopup, leftPopup, rightPopup, resolutionPopup, fpsPopup, qualityPopup, codecPopup, cursorButton, countdownButton, refreshButton, folderButton]
        for (key, popup) in [("resolution", resolutionPopup), ("fps", fpsPopup), ("quality", qualityPopup), ("codec", codecPopup)] {
            if defaults.object(forKey: key) != nil { popup.selectItem(at: max(0, min(popup.numberOfItems - 1, defaults.integer(forKey: key)))) }
        }
        window.contentView!.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 630, height: root.fittingSize.height + 72))
    }
    func buildMenu() {
        let appMenu = NSMenu(), mainMenu = NSMenu(), appItem = NSMenuItem()
        appMenu.addItem(withTitle: "Выйти из Able Recorder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem); NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◉ AR"
        let menu = NSMenu()
        menu.addItem(withTitle: "Открыть Able Recorder", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Начать / остановить запись", action: #selector(toggleRecording), keyEquivalent: "").target = self
        menu.addItem(.separator()); menu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<RecorderApp>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { app.toggleRecording() }; return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        let id = EventHotKeyID(signature: 0x4C525243, id: 1)
        let code = RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey | shiftKey), id, GetApplicationEventTarget(), 0, &hotkey)
        if code != noErr { status.stringValue = "Горячая клавиша занята. Используй кнопку или строку меню." }
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func applicationDidBecomeActive(_ notification: Notification) { updatePermissionStatus() }
    func updatePermissionStatus() {
        let screen = CGPreflightScreenCaptureAccess() ? "разрешён" : "нужен доступ"
        let audio: String
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: audio = "разрешён"
        case .denied: audio = "отключён"
        case .restricted: audio = "ограничен системой"
        case .notDetermined: audio = "нужен доступ"
        @unknown default: audio = "неизвестен"
        }
        permissionStatus.stringValue = "Экран: \(screen)  •  Аудиовход: \(audio)"
    }
    @objc func openScreenSettings() { openPrivacySettings(.screen) }
    @objc func openAudioSettings() { openPrivacySettings(.microphone) }
    func openPrivacySettings(_ pane: PrivacyPane) {
        if !NSWorkspace.shared.open(pane.url) {
            let fallback = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")!
            if !NSWorkspace.shared.open(fallback) { showError("Не удалось открыть Системные настройки. Открой Конфиденциальность и безопасность через меню Apple.") }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard mode != "idle" else { return .terminateNow }
        if mode == "recording" || mode == "monitor" { Task { await finishSession(); NSApp.reply(toApplicationShouldTerminate: true) }; return .terminateLater }
        if mode == "stopping" { return .terminateCancel }
        mode = "idle"; return .terminateNow
    }
    @objc func refreshDevices() {
        guard mode == "idle" else { return }
        inputs = Devices.inputs(); devicePopup.removeAllItems()
        devicePopup.addItems(withTitles: inputs.map { "\($0.name) · \($0.channels) входов" })
        if let uid = defaults.string(forKey: "device"), let index = inputs.firstIndex(where: { $0.uid == uid }) { devicePopup.selectItem(at: index) }
        var count: UInt32 = 0; CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count)); CGGetActiveDisplayList(count, &ids, &count)
        displays = Array(ids.prefix(Int(count))); displayPopup.removeAllItems()
        for (i, id) in displays.enumerated() {
            let name = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }?.localizedName ?? "Экран"
            displayPopup.addItem(withTitle: "\(i + 1). \(name) · \(CGDisplayPixelsWide(id)) × \(CGDisplayPixelsHigh(id))")
        }
        let saved = UInt32(defaults.integer(forKey: "display"))
        if let i = displays.firstIndex(of: saved) { displayPopup.selectItem(at: i) }
        else if let i = displays.firstIndex(where: { CGDisplayIsBuiltin($0) == 0 }) { displayPopup.selectItem(at: i) }
        updateChannels(); updateSpecs()
        if inputs.isEmpty { status.stringValue = "Аудиовходы не найдены. Подключи карту и нажми ↻." }
        else if displays.isEmpty { status.stringValue = "Экраны не найдены. Нажми ↻." }
        else { status.stringValue = "Выбери экран и проверь, что индикаторы L / R реагируют на Ableton." }
        mainButton.isEnabled = !inputs.isEmpty && !displays.isEmpty; monitorButton.isEnabled = !inputs.isEmpty
    }
    var selectedDevice: InputDevice? { inputs.indices.contains(devicePopup.indexOfSelectedItem) ? inputs[devicePopup.indexOfSelectedItem] : nil }
    func updateChannels() {
        leftPopup.removeAllItems(); rightPopup.removeAllItems()
        guard let device = selectedDevice else { return }
        for i in 1...device.channels {
            let title = "\(i)" + (device.isAudient && device.channels == 12 && i >= 11 ? " · Loopback" : "")
            leftPopup.addItem(withTitle: title); rightPopup.addItem(withTitle: title)
        }
        let pair = device.isAudient && device.channels == 12 ? (11, 12) : (1, min(2, device.channels))
        let left = defaults.integer(forKey: "left-" + device.uid), right = defaults.integer(forKey: "right-" + device.uid)
        leftPopup.selectItem(at: left > 0 && left <= device.channels ? left - 1 : pair.0 - 1)
        rightPopup.selectItem(at: right > 0 && right <= device.channels ? right - 1 : pair.1 - 1)
        audioHint.stringValue = device.isAudient && device.channels == 12 ? "iD14 MKII: в iD Mixer выбери Loopback Source → DAW 1+2, если Ableton играет на 1/2." : "Выбери реальные loopback-каналы карты. Один и тот же вход L/R даст моно."
    }
    @objc func selectionChanged(_ sender: NSPopUpButton) {
        if sender === devicePopup { updateChannels() }
        if let device = selectedDevice {
            defaults.set(device.uid, forKey: "device"); defaults.set(leftPopup.indexOfSelectedItem + 1, forKey: "left-" + device.uid); defaults.set(rightPopup.indexOfSelectedItem + 1, forKey: "right-" + device.uid)
        }
        if displays.indices.contains(displayPopup.indexOfSelectedItem) { defaults.set(Int(displays[displayPopup.indexOfSelectedItem]), forKey: "display") }
        for (key, popup) in [("resolution", resolutionPopup), ("fps", fpsPopup), ("quality", qualityPopup), ("codec", codecPopup)] { defaults.set(popup.indexOfSelectedItem, forKey: key) }
        updateSpecs()
    }
    var dimensions: (Int, Int) {
        guard displays.indices.contains(displayPopup.indexOfSelectedItem) else { return (1920, 1080) }
        let id = displays[displayPopup.indexOfSelectedItem], w = CGDisplayPixelsWide(id), h = CGDisplayPixelsHigh(id)
        guard w > 0, h > 0 else { return (1920, 1080) }
        let limit = [1080, 1440, 2160, h][max(0, resolutionPopup.indexOfSelectedItem)]
        let ratio = min(1.0, Double(limit) / Double(h))
        return (max(2, Int(Double(w) * ratio) / 2 * 2), max(2, Int(Double(h) * ratio) / 2 * 2))
    }
    var fps: Int { fpsPopup.indexOfSelectedItem == 1 ? 60 : 30 }
    var bitrate: Int { VideoPreset.all[max(0, qualityPopup.indexOfSelectedItem)].bitrate(width: dimensions.0, height: dimensions.1, fps: fps) }
    func updateSpecs() { let (w, h) = dimensions; spec.stringValue = String(format: "%d × %d · %d fps · ~%.1f Мбит/с · ~%.0f МБ/мин · AAC stereo 256 кбит/с", w, h, fps, Double(bitrate) / 1e6, Double(bitrate + 256000) * 60 / 8 / 1e6) }
    func updateFolder() { folderLabel.stringValue = (folder.path as NSString).abbreviatingWithTildeInPath; folderLabel.toolTip = folder.path }
    @objc func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Сохранять здесь"
        if panel.runModal() == .OK, let url = panel.url { folder = url; defaults.set(url.path, forKey: "folder"); updateFolder() }
    }
    @objc func revealLast() { if let lastFile { NSWorkspace.shared.activateFileViewerSelecting([lastFile]) } }
    func microphonePermission() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        updatePermissionStatus()
        guard granted else { throw PrivacyAccessError(pane: .microphone) }
    }
    func configureCallbacks(_ value: RecordingSession) {
        value.onMeter = { [weak self, weak value] l, r, dropped in DispatchQueue.main.async {
            guard let self, let value, self.session === value else { return }; self.meter.set(l, r); self.ringDrops = dropped
            if max(l, r) > 0.0001 { self.lastSignal = Date() }
        } }
        value.onStats = { [weak self, weak value] _, vd, ad in DispatchQueue.main.async { guard let self, let value, self.session === value else { return }; self.videoDrops = vd; self.audioDrops = ad } }
        value.onFailure = { [weak self, weak value] error in DispatchQueue.main.async {
            guard let self, let value, self.session === value, self.mode == "recording" || self.mode == "monitor" else { return }
            self.pendingError = error.localizedDescription; Task { await self.finishSession() }
        } }
    }
    func setBusy(_ value: String) {
        mode = value
        controls.forEach { $0.isEnabled = value == "idle" }
        mainButton.isEnabled = value == "idle" || value == "recording"
        monitorButton.isEnabled = value == "idle" || value == "monitor"
        mainButton.title = value == "recording" ? "■ Остановить запись" : "Начать запись"
        monitorButton.title = value == "monitor" ? "Остановить проверку" : "Проверить звук"
    }
    @objc func toggleMonitor() {
        if mode == "monitor" { Task { await finishSession() }; return }
        guard mode == "idle", let device = selectedDevice else { return }
        setBusy("starting")
        Task { do {
            try await microphonePermission()
            let value = RecordingSession(); session = value; configureCallbacks(value)
            try value.monitor(device: device, left: leftPopup.indexOfSelectedItem + 1, right: rightPopup.indexOfSelectedItem + 1)
            lastSignal = Date(); setBusy("monitor"); status.stringValue = "Проверка входов. Запусти звук в Ableton и следи за L / R."
        } catch { session = nil; setBusy("idle"); showError(error) } }
    }
    @objc func toggleRecording() {
        if mode == "recording" { Task { await finishSession() }; return }
        guard mode == "idle", let device = selectedDevice, displays.indices.contains(displayPopup.indexOfSelectedItem) else { showWindow(); return }
        setBusy("starting"); status.stringValue = "Подготовка записи…"
        Task { do {
            try await microphonePermission()
            guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { updatePermissionStatus(); throw PrivacyAccessError(pane: .screen) }
            updatePermissionStatus()
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let id = displays[displayPopup.indexOfSelectedItem]
            guard let display = content.displays.first(where: { $0.displayID == id }) else { throw RecorderError(message: "Выбранный экран отключён. Обнови список экранов.") }
            guard Devices.alive(device.id), abs(Devices.rate(device.id) - device.rate) < 1 else { throw RecorderError(message: "Аудиокарта изменилась. Обнови список устройств.") }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let url = folder.appendingPathComponent("Recording_\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(4)).mp4")
            if countdownButton.state == .on { for second in (1...3).reversed() { status.stringValue = "Запись через \(second)…"; try await Task.sleep(nanoseconds: 1_000_000_000) } }
            let value = RecordingSession(); session = value; configureCallbacks(value); pendingFile = url
            let (w, h) = dimensions
            try await value.start(display: display, device: device, left: leftPopup.indexOfSelectedItem + 1, right: rightPopup.indexOfSelectedItem + 1, width: w, height: h, fps: fps, bitrate: bitrate, hevc: codecPopup.indexOfSelectedItem == 1, cursor: cursorButton.state == .on, url: url, content: content)
            startDate = Date(); lastSignal = Date(); videoDrops = 0; audioDrops = 0; ringDrops = 0; pendingError = nil; setBusy("recording")
            status.stringValue = "Запись началась. ⌃⇧R — остановить."
        } catch {
            if let session { _ = await session.stop() }; session = nil; pendingFile = nil; setBusy("idle"); showError(error)
        } }
    }
    func finishSession() async {
        guard let current = session, mode != "stopping" else { return }
        let wasRecording = mode == "recording"; setBusy("stopping"); status.stringValue = "Завершаю MP4…"
        let (result, summary) = await current.stop(); session = nil; pendingFile = nil; startDate = nil; meter.set(0, 0); setBusy("idle"); statusItem.button?.title = "◉ AR"
        if let result {
            switch result {
            case .success(let url): lastFile = url; revealButton.isEnabled = true; status.stringValue = "Сохранено: \(url.lastPathComponent)\n\(summary)"
            case .failure(let error): showError(error)
            }
        } else { status.stringValue = wasRecording ? "Запись не создана." : "Проверка звука остановлена." }
        if let pendingError { self.pendingError = nil; showError(pendingError) }
    }
    func updateTick() {
        if mode == "monitor", Date().timeIntervalSince(lastSignal) > 3 { status.stringValue = "На выбранных каналах тишина. Проверь воспроизведение в Ableton и Loopback Source в микшере карты." }
        guard mode == "recording", let startDate else { return }
        let seconds = Int(Date().timeIntervalSince(startDate)), time = String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        var megabytes = 0.0
        if let pendingFile { let partial = pendingFile.deletingPathExtension().appendingPathExtension("partial.mp4"); megabytes = Double((try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1e6 }
        let drops = videoDrops + audioDrops + Int(ringDrops)
        status.stringValue = "● \(time) · \(String(format: "%.1f", megabytes)) МБ" + (drops > 0 ? " · пропуски: \(drops)" : "") + (Date().timeIntervalSince(lastSignal) > 3 ? "\nЗвук: тишина на выбранных входах." : "")
        statusItem.button?.title = "● \(time)"
        if CGDisplayIsActive(displays[displayPopup.indexOfSelectedItem]) == 0 { pendingError = "Выбранный экран отключён."; Task { await finishSession() } }
    }
    func showError(_ error: Error) { showError(error.localizedDescription, privacy: (error as? PrivacyAccessError)?.pane) }
    func showError(_ text: String, privacy: PrivacyPane? = nil) {
        status.stringValue = text
        let alert = NSAlert(); alert.messageText = "Able Recorder"; alert.informativeText = text; alert.alertStyle = .warning
        if let privacy {
            alert.addButton(withTitle: "Открыть настройки"); alert.addButton(withTitle: "Закрыть")
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn { self?.openPrivacySettings(privacy) }
            }
        } else { alert.beginSheetModal(for: window) }
    }

    func exportUICheck(to folder: URL) throws {
        guard let view = window.contentView else { throw RecorderError(message: "No content view") }
        view.layoutSubtreeIfNeeded()
        guard mainButton.window === window, displayPopup.numberOfItems > 0, devicePopup.numberOfItems > 0 else { throw RecorderError(message: "Recorder UI did not finish initializing") }
        let buttonRect = mainButton.convert(mainButton.bounds, to: view)
        guard view.bounds.contains(buttonRect) else { throw RecorderError(message: "Record button clipped: \(buttonRect), content \(view.bounds)") }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw RecorderError(message: "No UI bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw RecorderError(message: "No PNG") }
        try png.write(to: folder.appendingPathComponent("interface.png"))
        print("UI PASS: content \(view.bounds); record button \(buttonRect); \(devicePopup.titleOfSelectedItem ?? "none"); L \(leftPopup.titleOfSelectedItem ?? "none"), R \(rightPopup.titleOfSelectedItem ?? "none")")
    }
}

extension NSBox {
    static func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; box.widthAnchor.constraint(equalToConstant: 574).isActive = true; return box }
}
