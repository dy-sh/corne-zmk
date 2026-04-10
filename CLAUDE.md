# ZMK Jorne Keyboard Project

## Hardware

- Клавиатура: Jorne-WL v3.0.1 (сплит, беспроводная)
- Контроллеры: nice!nano v2
- Физических клавиш: 42 (как у Corne)
- Shield в ZMK: `jorne` (матрица 44 позиции)

## Jorne vs Corne — ключевое отличие

Jorne shield определяет **44 позиции**, а Corne — **42**. Разница: у Jorne в первом ряду есть 2 дополнительные крайние позиции (0 и 13), которые физически отсутствуют на нашей клавиатуре. Они заполняются `&none`.

Поэтому Corne keymap файлы **нельзя использовать напрямую** — они не скомпилируются из-за несовпадения количества bindings в первом ряду.

## Как конвертировать Corne keymap в Jorne

### Матрица позиций

**Corne (42 позиции):**
```
 0   1   2   3   4   5       6   7   8   9  10  11
12  13  14  15  16  17      18  19  20  21  22  23
24  25  26  27  28  29      30  31  32  33  34  35
            36  37  38      39  40  41
```

**Jorne (44 позиции):**
```
 0   1   2   3   4   5   6       7   8   9  10  11  12  13
    14  15  16  17  18  19      20  21  22  23  24  25
    26  27  28  29  30  31      32  33  34  35  36  37
                38  39  40      41  42  43
```

Позиции 0 и 13 — фантомные (`&none`), физически клавиш нет.

### Шаги конвертации

**1. Первый ряд каждого слоя — добавить `&none` по краям:**

Corne:
```
&kp ESC  &kp Q  &kp W  &kp E  &kp R  &kp T    &kp Y  &kp U  &kp I  &kp O  &kp P  &kp BSPC
```

Jorne:
```
&none  &kp ESC  &kp Q  &kp W  &kp E  &kp R  &kp T    &kp Y  &kp U  &kp I  &kp O  &kp P  &kp BSPC  &none
```

**2. Второй и третий ряды, thumb-кластер — без изменений.**

Количество клавиш совпадает (по 12 во 2-3 рядах, 6 в thumb).

**3. Пересчитать key-positions в combos и behaviors:**

Из-за сдвига нумерации (позиция 0 теперь фантомная) все номера клавиш сдвигаются. Правило:

| Corne ряд | Corne позиции | Jorne позиции | Сдвиг |
|-----------|--------------|--------------|-------|
| Ряд 1     | 0-11         | 1-12         | +1    |
| Ряд 2     | 12-23        | 14-25        | +2    |
| Ряд 3     | 24-35        | 26-37        | +2    |
| Thumbs    | 36-41        | 38-43        | +2    |

Пример: combo на Corne `key-positions = <0 1>` (Q+W) -> на Jorne `key-positions = <1 2>`.
Combo на Corne `key-positions = <36 37>` (left thumbs) -> на Jorne `key-positions = <38 39>`.

**4. Заменить shield-зависимые настройки:**

В `build.yaml`:
- `corne_left` -> `jorne_left`
- `corne_right` -> `jorne_right`

Имя keymap-файла: `corne.keymap` -> `jorne.keymap`
Имя conf-файла: `corne.conf` -> `jorne.conf`

## Версия ZMK

- **ZMK v0.3.0** (закреплена в `config/west.yml` и `.github/workflows/build.yml`)
- **Board**: `nice_nano_v2`
- **Shields**: `jorne_left`, `jorne_right`, `settings_reset`

**Почему v0.3.0, а не main:** ZMK main включает Zephyr 4.1 с переименованием board definitions (`nice_nano_v2` → `nice_nano@2.0.0`). v0.3.0 гарантирует совместимость.

## Синхронизация AHK-скрипта

При изменении блока AHK в `README.md` (раздел Windows — AutoHotkey, между ` ```autohotkey ` и закрывающими ` ``` `) **сразу же** применять идентичные изменения к реальному файлу пользователя:

`C:\Users\user\Documents\Autohotkey\CapsLock Escape.ahk`

README — это шаблон, рабочий скрипт лежит отдельно. Не оставлять пользователю задачу копировать вручную — менять оба файла в одном flow.

## Структура репозитория

- `config/jorne.keymap` — раскладка (3 слоя: base, L1 symbols/BT, L2 numbers/nav)
- `config/jorne.conf` — настройки прошивки
- `config/west.yml` — манифест зависимостей ZMK
- `build.yaml` — матрица сборки для GitHub Actions
- `.github/workflows/build.yml` — workflow сборки
- `firmware/` — собранные прошивки (.uf2)
- `docs/` — документация

## Раскладка

**3 слоя**: base (QWERTY + hold-tap модификаторы), L1 (символы, BT), L2 (цифры, навигация, медиа).

**Custom behaviors**: `hml`/`hmr` (hold-tap модификаторы), `tkl`/`tkr` (layer toggle).

## Сборка

Push в main запускает GitHub Actions. Workflow: `.github/workflows/build.yml`.
Ручной запуск: `gh workflow run build.yml`.

## Прошивка контроллеров

1. Подключить USB-C, двойной клик RESET (появится USB диск)
2. Скопировать `.uf2` файл на диск
3. Повторить для второй половины
4. Подключиться через Bluetooth (устройство "Corne")

**Сброс Bluetooth**: прошить `settings_reset-nice_nano_v2-zmk.uf2` на обе половины, затем нормальные прошивки.

## ZMK Studio

Включен для левой половины (USB). Для разблокировки в keymap должен быть binding `&studio_unlock`.
Сейчас он на слое L1, позиция правого Shift (L1 + правый нижний угол).

## Частые ошибки

| Ошибка | Решение |
|---|---|
| "No board named 'nice_nano_v2' found" | Используется main ZMK вместо v0.3.0 |
| Клавиатура не видна в Bluetooth | Прошить settings_reset на обе половины, потом нормальную |
| Keymap не компилируется | Проверить 44 позиции и поддержку keycodes в v0.3.0 |
