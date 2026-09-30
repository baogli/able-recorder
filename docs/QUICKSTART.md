# First recording / Первый ролик

## Audio routing

Able Recorder reads two selected input channels from one macOS Core Audio device. Your DAW can keep using the same interface as its output. Selecting a device in the recorder does not change the system default input/output or the DAW's settings.

For hardware loopback, configure the source in your interface's mixer first. A microphone input records a microphone; it will not automatically become the DAW mix. On an interface with no loopback, use an already installed virtual input device or an external physical route appropriate to your setup.

For [Audient iD14 MKII](https://support.audient.com/hc/en-us/articles/360055049331-ID14-Loop-back-Setup), loopback reaches inputs 11/12. Select DAW 1+2 if the DAW outputs there, or the appropriate source/mix. iD14 MKI does not provide hardware loopback. Able Recorder suggests 11/12 on an Audient input device with 12 channels; verify the actual model and routing.

## Controls

| Russian interface | Action |
| --- | --- |
| Экран | Select display; ↻ refreshes the list after connecting a monitor |
| Аудиокарта | Select input device |
| Входы L / R | Select independent source channels; same channel twice gives mono |
| Проверить звук | Start/stop input meters before recording |
| Доступ к экрану… | Open macOS screen capture privacy settings |
| Доступ к аудио… | Open macOS microphone privacy settings |
| Видео / Качество | Select resolution, frame rate, codec and quality |
| Сохранение → Изменить… | Select output folder |
| Начать запись | Start recording; the button becomes Stop |
| Последний MP4 ↗ | Reveal completed recording |

The initial preset for web publishing is 1080p / 30 fps / Для публикации / H.264. Higher frame rates and quality increase file size. “1080p” is a maximum height, not forced 16:9. Native display aspect ratio is preserved and small displays are not enlarged.

## Ten-second acceptance test

1. Put your DAW on the intended display; choose that display in the recorder.
2. Play a stereo part. Check both meters and confirm the inputs correspond to the intended mix.
3. Record ten seconds while moving a visible control in time with an audible change.
4. Stop and play the MP4. Confirm correct screen, L/R sound, acceptable sync and readable DAW controls.
5. If silence is reported, check the interface loopback source and DAW output pair. If access is denied, use the app's settings buttons and reopen the app if macOS requests it.

A sound-check meter does not send audio to your speakers. The recorder has no live monitoring output. Selecting an input that already receives a feedback loop from other software can still record that loop.
