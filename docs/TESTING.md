# Verified coverage

Version 0.2.0 is a preview, not a hardware compatibility certification.

## Synthetic media

The native `--self-test` encodes and fully decodes:

| Video | Input PCM rate | Target audio |
| --- | --- | --- |
| H.264 / 30 fps | 48 kHz | AAC stereo / 48 kHz |
| H.264 / 60 fps | 44.1 kHz | AAC stereo / 48 kHz |
| HEVC / 30 fps | 96 kHz | AAC stereo / 48 kHz |

Assertions cover frame/audio counts, duration, a held final frame, independent 1000/1500 Hz L/R content and amplitudes, sample-rate conversion, an empty-recording rejection and `moov` before `mdat` in the finished MP4. Generated recordings stay in the ignored `Tests/output` directory.

The 0.2.0 build passed all three cases on 2026-10-01 (local time). Machine-readable measurements are in [validation-0.2.0.json](validation-0.2.0.json). The native window layout check also passed, with the record button visible inside a 642 × 731 content area. Final screenshot review after renaming requires an unlocked Mac session.

## Local capture

The original transport check used one Apple Silicon Mac, its built-in display and Audient input channels 11/12. It produced a 3.003-second MP4 with 88 video frames, one video and one audio track, and zero reported input/video drops. The audio was nearly silent. This verifies capture and container transport; it does not prove an Ableton music recording or external-display behavior.

The physical audio diagnostic received 187 input packets in two seconds. Input content, every interface, Intel Macs, hotplug behavior under every device driver, long-session drift and recordings on a second monitor are not all independently validated. Please use the [ten-second acceptance test](QUICKSTART.md) before recording an important session.

The app's permission links and status are exposed in the native UI. macOS permission grants must be made by the user in System Settings.
