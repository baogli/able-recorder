# Able Recorder 0.2.0 · First open-source preview

Free Mac screen recording for musicians. Choose your display and input channels, record straight to MP4.

## Download

- **Able-Recorder-0.2.0-macOS-arm64.zip** — macOS 14+ / Apple Silicon.
- **.sha256** — SHA-256 checksum of the app archive.
- Source archives and the editable marketing kit are available in the repository.

Extract the ZIP, move Able Recorder.app to Applications, and open it. Grant Screen Recording and Microphone access using the app's settings shortcuts. For hardware loopback, configure the source in your interface mixer and choose the actual L/R channel numbers.

This is an **ad-hoc signed preview without Apple notarization**. macOS may require manual approval through System Settings → Privacy & Security. The UI is currently Russian.

## Included

Selectable display and Core Audio device/channel pair; L/R sound check; H.264/HEVC + AAC MP4; resolution/frame-rate/quality controls; menu-bar controls and Control–Shift–R; MIT source; English/Russian docs; original icon and editable press kit.

## Validation and limits

The 0.2.0 native synthetic tests passed real encoding and full decoding for H.264 30/60 fps and HEVC 30 fps, stereo isolation, 44.1/48/96 kHz input conversion, final-frame duration and fast-start MP4 layout. Native window layout checks passed. See `docs/validation-0.2.0.json` for measurements.

The earlier physical transport check captured one built-in display with Audient inputs 11/12, with nearly silent audio. A musical Ableton session on a second display remains a user acceptance test. Other interface models and Intel runtime capture are not independently certified.

This preview records local files. Live broadcasting is not implemented.
