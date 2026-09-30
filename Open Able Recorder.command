#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ ! -x "build/Able Recorder.app/Contents/MacOS/AbleRecorder" ]]; then
  ./build.sh
fi
open "build/Able Recorder.app"
