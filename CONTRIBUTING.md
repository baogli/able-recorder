# Contributing

Bug reports, interface feedback and pull requests are welcome. Start with a small reproducible problem and describe the resulting behavior.

For a capture bug, include macOS version, Mac architecture, interface model, driver/mixer version, sample rate, input channel numbers, display resolution and video preset. Do not upload a screen recording containing private projects, device UIDs or personal paths. A short synthetic reproduction is best.

Build with `./build.sh`; run `--self-test` for media pipeline changes and `--ui-check` for layout changes. Device-specific changes need a real-device test with stated limits. Run checks appropriate to the change; avoid replacing the native audio callback with allocating or blocking code.

Source and original artwork contributions are licensed under the project's MIT license. Keep separately licensed third-party assets and their notices intact.
