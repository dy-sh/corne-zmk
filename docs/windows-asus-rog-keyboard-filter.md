# Jorne не печатает в Windows на ASUS/ROG системе

## Что это за проблема

На Windows-ПК с ASUS motherboard, Armoury Crate, ASUS Framework Service, Aura/LightingService или ROG-периферией Jorne может быть видна как подключенная, показывать заряд батареи и успешно проходить pairing, но не печатать.

Симптом может начинаться как Bluetooth-проблема, но затем проявляться и по USB. Если та же Jorne работает на macOS по Bluetooth и USB, а в Windows не вводит символы, причина, скорее всего, не в прошивке ZMK и не в самой клавиатуре, а в Windows keyboard input stack.

На проблемной системе был найден лишний ASUS/ROG upper filter driver в общем классе клавиатур:

```text
UpperFilters = keyboard, kbdclass
```

Нормальное состояние:

```text
UpperFilters = kbdclass
```

`kbdclass` - штатный драйвер Windows. `keyboard` - сторонний ASUS/ROG filter driver. В найденном случае он был связан с пакетом `rogkb.inf` от `ASUSTeK Computer Inc.` и ломал ввод Jorne.

## Быстрая диагностика

Проверить keyboard class filters:

```powershell
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}" /v UpperFilters
```

Если вывод содержит только `kbdclass`, этот конкретный ASUS/ROG filter сейчас не активен:

```text
UpperFilters    REG_MULTI_SZ    kbdclass
```

Если вывод содержит `keyboard` перед `kbdclass`, это подозрительное состояние:

```text
UpperFilters    REG_MULTI_SZ    keyboard\0kbdclass
```

Проверить, какой пакет ASUS/ROG установлен для клавиатур:

```powershell
pnputil /enum-drivers | Select-String -Pattern "ASUSTeK|ASUS|ROG|rogkb|Keyboard" -Context 2,8
```

Типичный подозрительный пакет:

```text
Original Name:      rogkb.inf
Provider Name:      ASUSTeK Computer Inc.
Class Name:         Keyboard
```

Проверить, какие keyboard devices используют ASUS/ROG драйверы:

```powershell
pnputil /enum-devices /class Keyboard /drivers
```

Если в системе есть ROG OMNI RECEIVER, он может быть составным HID-устройством: mouse interface, keyboard interface, consumer control и vendor-defined HID interfaces. Поэтому ASUS/ROG-мышь или ее приемник могут косвенно установить keyboard filter, даже если проблема проявляется на Jorne.

## Как исправить вручную

Перед изменением реестра желательно сделать backup ключа:

```powershell
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}" keyboard-class-backup.reg
```

Открыть PowerShell от администратора и оставить в `UpperFilters` только штатный `kbdclass`:

```powershell
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}" `
  -Name UpperFilters `
  -Type MultiString `
  -Value @("kbdclass")
```

После этого проверить:

```powershell
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}" /v UpperFilters
```

Ожидаемый результат:

```text
UpperFilters    REG_MULTI_SZ    kbdclass
```

Затем переподключить Jorne по Bluetooth или USB. Если ввод не ожил сразу, перезагрузить Windows.

## Что делать после перезагрузки

Проверить, не вернул ли ASUS/ROG software stack фильтр обратно:

```powershell
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}" /v UpperFilters
```

Если снова появилось:

```text
UpperFilters    REG_MULTI_SZ    keyboard\0kbdclass
```

значит фильтр заново добавляет ASUS/ROG компонент: драйверный пакет, служба, scheduled task или companion app.

## Как искать источник

Проверить ASUS/ROG драйверные пакеты:

```powershell
pnputil /enum-drivers | Select-String -Pattern "ASUSTeK|ASUS|ROG|rogkb|rogms|Keyboard|Mouse" -Context 2,8
```

Проверить keyboard и mouse devices:

```powershell
pnputil /enum-devices /class Keyboard /drivers
pnputil /enum-devices /class Mouse /drivers
```

Проверить службы ASUS/ROG:

```powershell
Get-Service | Where-Object {
  $_.Name -match "ASUS|ROG|Armoury|Aura" -or
  $_.DisplayName -match "ASUS|ROG|Armoury|Aura"
} | Sort-Object Name | Format-Table Status,Name,DisplayName
```

Проверить scheduled tasks:

```powershell
Get-ScheduledTask | Where-Object {
  $_.TaskName -match "ASUS|ROG|Armoury|Aura" -or
  $_.TaskPath -match "ASUS|ROG|Armoury|Aura"
} | Select-Object TaskPath,TaskName,State
```

Проверить установленные ASUS/ROG приложения:

```powershell
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
  Where-Object { $_.DisplayName -match "ASUS|ROG|Armoury|Aura" } |
  Select-Object DisplayName,DisplayVersion,Publisher,InstallDate
```

Кандидаты:

- Armoury Crate
- Armoury Crate Service
- ASUS Framework Service
- Aura / LightingService
- ROG keyboard components
- ROG mouse / ROG OMNI RECEIVER components

## Что не нужно менять

Не нужно менять ZMK sleep-настройки ради этой проблемы. Если Jorne работает на другой ОС и начинает печатать после удаления ASUS/ROG filter, корень проблемы находится в Windows keyboard class stack.

Не нужно перепрошивать Jorne без других признаков проблемы прошивки.

Не нужно постоянно удалять и заново создавать Bluetooth pairing: это может временно менять симптомы, но не исправляет `UpperFilters`.
