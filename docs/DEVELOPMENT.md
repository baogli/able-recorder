# Development

## Build

`./build.sh` compiles C and Swift with Apple's command-line toolchain, links system frameworks, adds the icon and ad-hoc signs the app. Target: macOS 14, arm64. `ARCH=x86_64 ./build.sh` compiles for Intel but is not an Intel runtime certification. Run one architecture build at a time.

The bundle identifier `local.michael.LoopbackRecorder` and designated requirement are retained from the first local prototype to preserve previously granted permissions. The product and executable are Able Recorder / AbleRecorder. A future signed distribution should plan a permission migration before changing the identity.

## Pipeline

- `App.swift`: AppKit controls, preferences, permission links, menu bar and Carbon hotkey.
- `Devices.swift`: Core Audio input enumeration and display/video presets.
- `AudioBridge.c`: input-only AUHAL with an explicit hardware channel map; preallocated ring buffer and atomic indices. No Swift callbacks, allocation or locks on the hardware audio callback.
- `Capture.swift`: drain the audio ring, build stereo PCM samples, capture the display through ScreenCaptureKit, encode with AVAssetWriter and finish MP4.
- `SelfTest.swift`: synthetic media generator plus full decode validation.

Screen and audio timestamps share the host clock. The app excludes its own windows from capture. MP4 encodes in real time with AAC stereo at 48 kHz / 256 kbit/s; fast-start index placement is requested for completed files. Static screens are extended to the real stop time by holding the last frame.

When the selected device is disconnected, its sample rate changes, or the selected display disappears, the recorder stops and attempts to finalize the existing recording. Power loss and forced termination cannot guarantee a playable partial MP4.

## Commands

```sh
"build/Able Recorder.app/Contents/MacOS/AbleRecorder" --self-test "$PWD/Tests/output"
"build/Able Recorder.app/Contents/MacOS/AbleRecorder" --ui-check "$PWD/Tests/output/ui"
"build/Able Recorder.app/Contents/MacOS/AbleRecorder" --devices
"build/Able Recorder.app/Contents/MacOS/AbleRecorder" --audio-check
"build/Able Recorder.app/Contents/MacOS/AbleRecorder" --capture-check "$PWD/Tests/output"
```

`--devices` prints local device IDs and names: review before sharing. `--audio-check` and `--capture-check` are developer diagnostics for a connected 12-channel Audient device, using 11/12. They require existing permissions and do not request new ones. The capture diagnostic records the local display. Keep these private outputs out of commits.

Hardware codecs and capture devices may be unavailable in a restricted execution sandbox. Media validation should run in a normal Mac session. CI builds and packages the app; local capture is an additional check, not a claim made by the build alone.

## Artwork

Original icon and brand geometry are in `assets/logo.svg` and editable `marketing/designs/*.tsrct`. Install Tesseract CLI 0.3.0 separately and set `TSRCT=/path/to/tsrct` to regenerate with `python3 scripts/brand.py all`. The CLI is only a development tool; its license is separate and it is not redistributed. Inter is embedded in the design sources under its included OFL license.
