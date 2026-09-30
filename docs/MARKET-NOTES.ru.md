# Что есть на рынке — документация повторно проверена 1 октября 2026

| Программа | Документированный путь к каналам карты | Что означает для этого сценария |
|---|---|---|
| [Ecamm Live](https://support.ecamm.com/en/articles/3324007-adjusting-sound-levels) | Для каждого входного канала доступны Off / Mono / Left / Right | Есть нужный выбор 11/12; интерфейс предназначен также для live-производства. С Audient здесь не тестировался. |
| [iShowU Instant Advanced Features](https://support.shinywhitebox.com/hc/en-us/articles/206281803-iShowU-Instant-Tips) | Configure Channels назначает каналы входа выходным каналам | Подходящий принцип маршрутизации. Прямая работа 11/12 и совместимость этой версии с текущей macOS здесь не проверены. |
| [ScreenFlow](https://primary.telestream.net/screenflow/overview.htm) | Поддержка multichannel audio, редактор и экспорт | Более широкий рабочий процесс записи и редактирования. Прямая связка Audient 11/12 здесь не тестировалась. |
| [Screen Studio (screen.studio)](https://screen.studio/create/screen-recorder-with-audio) | Системное аудио всего Mac или выбранных приложений | Эта функция сама по себе не подтверждает выбор именно аппаратных loopback-входов 11/12. |

Актуальная [документация Audient](https://support.audient.com/hc/en-us/articles/360055049331-ID14-Loop-back-Setup) подтверждает loopback у iD14 MKII, входы 11+12 и источники DAW 1+2 / 3+4 / 5+6, Master Mix, Cue A/B. У iD14 MKI аппаратного loopback нет.

Основа видео: [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos); карта входных каналов: [Apple Audio Unit ChannelMap](https://developer.apple.com/documentation/audiotoolbox/kaudiooutputunitproperty_channelmap).


Фокус Able Recorder — бесплатная локальная запись музыкального процесса: один экран, одно входное устройство, явно выбранные L/R и MP4 сразу. Это самостоятельный сценарий продукта; сравнительного теста задержки, нагрузки и качества конкурентов здесь не было. Цены и подписки в этом обзоре не сравниваются.
