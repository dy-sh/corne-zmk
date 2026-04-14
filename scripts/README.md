# bt-kick.ps1 — аварийное восстановление BLE HID клавиатуры

Однокликовое восстановление связи с Jorne/ZMK клавиатурой после того, как Windows «теряет» её по Bluetooth, не требуя перезагрузки ПК.

## Ситуация

Jorne (ZMK, BLE HID) подключена к этому ПК через **TP-Link UB500/UB5A** (BT 5.4, чип Realtek RTL8761). Симптомы:

- После ~15 минут простоя клавиатура перестаёт слать нажатия.
- В «Параметры → Bluetooth» устройство по-прежнему показано как **Connected**.
- Переключение ZMK-профиля на MacBook доказывает, что сама клавиатура исправна.
- До появления этого скрипта единственным способом вернуть ввод была полная перезагрузка Windows.

## Почему так происходит

Диагностика на живой системе показала, что причина — не в клавиатуре и не в прошивке ZMK, а в связке Windows BT стека с адаптером Realtek и фильтр-драйвером TP-Link:

1. **BTHUSB Event ID 31** в системном журнале: *«The local adapter does not support the minimum buffer requirement to support the hardware filtering of Bluetooth Low Energy advertisements.»* Известная проблема Realtek-адаптеров: Windows откатывается на программную фильтрацию BLE-рекламы, и в сочетании с прошивкой Realtek это приводит к потере GATT-нотификаций HID-over-GATT после простоя линка. Центральный (ПК) всё ещё думает, что периферия подключена, но подписка на HID-отчёты фактически мертва.
2. Поверх адаптера сидит фильтр-драйвер **`RtkBtFilter`** (пакет `oem88.inf` / `rtkfilter.inf`, TP-Link Systems, v1.9.1038.3023). Пользователи ZMK массово сообщают, что именно этот фильтр ломает переподключение BLE HID.
3. **BTHUSB Event 18** — *«Windows cannot store Bluetooth authentication codes…»* — тоже указывает на проблемы уровня прошивки/драйвера Realtek.
4. Hibernate, S0 low-power idle и Fast Startup на этой машине отключены, план питания — High Performance. Power-management как причина исключён.

## Идея работы скрипта

Скрипт целево «софт-ребутит» только BT-подсистему, не трогая остальную ОС и сопряжение с клавиатурой. Занимает ~5 секунд, повторный pairing не нужен.

Механика через `pnputil` на уровне PnP-менеджера Windows:

1. **Основной путь**: `pnputil /disable-device` → пауза 2 с → `pnputil /enable-device`. Это самый надёжный способ на Windows 11 — гарантированно сносит все подписки GATT и заново поднимает стек `bthport` / `bthusb` / `BTHLEEnum` поверх свежего адаптера.
2. **Фоллбэк**: `pnputil /restart-device` — более мягкий перезапуск одним шагом. Используется, если `/disable-device` не сработал.

PowerShell-альтернативы `Disable-PnpDevice` / `Enable-PnpDevice` для USB-устройств **не работают**: CIM-провайдер `Win32_PnPEntity` отвечает `Not supported`. Поэтому скрипт вызывает `pnputil` напрямую.

### Важно: pending reboot блокирует `/restart-device`

На этой машине у адаптера выставлен `DEVPKEY_Device_IsRebootRequired = True` (следствие предыдущих манипуляций с драйвером). Пока флаг стоит, `pnputil /restart-device` возвращает:

```
Failed to restart device: USB\VID_2357&PID_0604\6C4CBC09ECB2
Device is pending system reboot to complete a previous operation.
```

**Разовая перезагрузка Windows снимает флаг**, после чего `/restart-device` работает штатно. Путь `/disable-device` + `/enable-device` этому флагу не подвержен и работает даже в pending-состоянии.

Скрипт привязан к конкретному адаптеру через его USB instance ID:

```
USB\VID_2357&PID_0604\6C4CBC09ECB2
```

Если поменяешь адаптер или порт — ID изменится, и строку `$instanceId` в `bt-kick.ps1` надо обновить. Посмотреть актуальный ID:

```powershell
Get-PnpDevice -Class Bluetooth | Where-Object { $_.InstanceId -like 'USB*' } |
  Select-Object FriendlyName, InstanceId
```

## Как пользоваться

1. На рабочем столе есть ярлык **`bt-kick`** (ведёт на этот скрипт, флаг «Run as administrator» уже выставлен).
2. Когда клавиатура «зависла» после простоя — двойной клик по ярлыку → UAC → Yes.
3. Окно PowerShell мигнёт и закроется, адаптер перечитается за ~5 с, клавиатура снова печатает.

Запуск вручную (админ PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\user\DEV\zmk-corne-new\scripts\bt-kick.ps1
```

### Ручной запуск шагов (если скрипт по какой-то причине недоступен)

```powershell
pnputil /disable-device "USB\VID_2357&PID_0604\6C4CBC09ECB2"
Start-Sleep -Seconds 2
pnputil /enable-device  "USB\VID_2357&PID_0604\6C4CBC09ECB2"
```

## Чего скрипт НЕ делает

- Не чинит корень проблемы — `RtkBtFilter` / прошивка Realtek остаются как есть. Это сеть безопасности, а не фикс.
- Не трогает сопряжение, не удаляет драйверы, не меняет настройки питания.
- Не поможет, если клавиатура реально разряжена или вне радиуса.

## Настоящий фикс

Описан в плане `~/.claude/plans/peppy-crunching-bubble.md` (шаги 2–5): удаление пакета `oem88.inf` и откат на встроенный Microsoft `bth.inf`, отключение USB selective suspend, при необходимости — замена адаптера (Intel AX210 и подобные). Этот скрипт — страховка, которую стоит иметь под рукой и после применения настоящего фикса.

## Проверка журнала после инцидента

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='BTHUSB'} -MaxEvents 30 |
  Format-List TimeCreated, Id, LevelDisplayName, Message
```

Event 31 (warning) может всё равно появляться — это косметический варнинг о возможностях прошивки. Главное — отсутствие новых ошибок вокруг момента зависания.
