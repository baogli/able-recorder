import AppKit
import AVFoundation
import ScreenCaptureKit

if CommandLine.arguments.contains("--devices") {
    print("Microphone permission: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue) (0=not determined, 3=authorized)")
    for d in Devices.inputs() { print("\(d.id) | \(d.uid) | \(d.name) | \(d.channels) input channels | \(d.rate) Hz") }
    for s in NSScreen.screens { print("Display: \(s.localizedName) \(s.frame) scale \(s.backingScaleFactor)") }
} else if let index = CommandLine.arguments.firstIndex(of: "--self-test") {
    DispatchQueue.global().asyncAfter(deadline: .now() + 45) { fputs("SELF TEST TIMEOUT\n", stderr); exit(2) }
    let folder = CommandLine.arguments.count > index + 1 ? URL(fileURLWithPath: CommandLine.arguments[index + 1]) : URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AbleRecorderTests")
    Task { do { try await SelfTest.run(folder: folder); print("SELF TEST PASSED"); exit(0) } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) } }
    RunLoop.main.run()
} else if let index = CommandLine.arguments.firstIndex(of: "--ui-check") {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = RecorderApp(); app.delegate = delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do { try delegate.exportUICheck(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0) }
            catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
        app.run()
    }
} else if let index = CommandLine.arguments.firstIndex(of: "--capture-check") {
    guard CGPreflightScreenCaptureAccess(), AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { print("CAPTURE CHECK BLOCKED: app permissions must be granted first."); exit(3) }
    DispatchQueue.global().asyncAfter(deadline: .now() + 20) { fputs("CAPTURE CHECK TIMEOUT\n", stderr); exit(2) }
    let folder = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    Task { do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first, let device = Devices.inputs().first(where: { $0.isAudient && $0.channels == 12 }) else { throw RecorderError(message: "Display or Audient not found") }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("live-capture-\(UUID().uuidString.prefix(6)).mp4")
        let session = RecordingSession()
        var failure: String?
        session.onFailure = { error in failure = error.localizedDescription }
        try await session.start(display: display, device: device, left: 11, right: 12, width: 1280, height: 828, fps: 30, bitrate: 5_000_000, hevc: false, cursor: true, url: url, content: content)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let (result, summary) = await session.stop()
        if let failure { throw RecorderError(message: failure) }
        guard let result else { throw RecorderError(message: "No movie result") }
        let finished = try result.get()
        let asset = AVURLAsset(url: finished)
        let duration = try await asset.load(.duration).seconds
        let videos = try await asset.loadTracks(withMediaType: .video), audios = try await asset.loadTracks(withMediaType: .audio)
        guard duration > 2.5, videos.count == 1, audios.count == 1 else { throw RecorderError(message: "Invalid live MP4 tracks or duration: \(duration)") }
        let info: [String: Any] = ["file": finished.lastPathComponent, "duration": duration, "summary": summary, "device": device.name, "inputs": [11, 12], "displayID": display.displayID, "note": "Capture transport checked; Ableton music and external-display selection require user test."]
        try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("live-report.json"))
        print("CAPTURE CHECK PASS: \(info)"); exit(0)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) } }
    RunLoop.main.run()
} else if CommandLine.arguments.contains("--audio-check") {
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { print("AUDIO CHECK BLOCKED: grant microphone permission in the app first."); exit(3) }
    guard let device = Devices.inputs().first(where: { $0.isAudient && $0.channels == 12 }) else { print("AUDIO CHECK BLOCKED: Audient 12-channel input not found."); exit(3) }
    let queue = DispatchQueue(label: "audio-check")
    let audio = HardwareAudio(device: device)
    var packets = 0, peakL: Float = 0, peakR: Float = 0, failure: String?
    audio.onSample = { _ in packets += 1 }
    audio.onMeter = { l, r, _ in peakL = max(peakL, l); peakR = max(peakR, r) }
    audio.onFailure = { error in failure = error.localizedDescription }
    do { try audio.start(left: 11, right: 12, queue: queue) } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    queue.asyncAfter(deadline: .now() + 2) {
        audio.stop()
        if let failure { fputs("\(failure)\n", stderr); exit(1) }
        guard packets > 0 else { fputs("No HAL input packets\n", stderr); exit(1) }
        print("AUDIO CHECK PASS: \(device.name), inputs 11/12; \(packets) packets; peak L \(peakL), R \(peakR). Signal content requires an Ableton playback test."); exit(0)
    }
    RunLoop.main.run()
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = RecorderApp(); app.delegate = delegate
        app.run()
    }
}
