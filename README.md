# GlobalStay (Booking)

Клиентское Flutter-приложение для бронирования жилья. Макет: [Figma — Booking](https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking).

## Что сделано

Реализован стартовый поток по макету (вариант онбординга 1) и проверен на эмуляторе **Pixel**.

**Сплэш**
- Белый экран, по центру логотип GlobalStay (`images/logo.svg`)
- Показ ~1.8 с, параллельно прогреваются картинки онбординга
- Затем fade-переход на онбординг

**Онбординг (3 экрана)**
| Экран | Заголовок | Фон |
| --- | --- | --- |
| 1 | Находите идеальное жилье | `images/onbordins.v1/01-find-housing.png` |
| 2 | Бронируйте жилье уверенно | `images/onbordins.v1/02-book-confidently.png` |
| 3 | Путешествуйте без границ | `images/onbordins.v1/03-travel-without-borders.png` |

- Полноэкранное фото, градиент снизу, индикатор страниц, кнопки **Далее** / **Начать**
- Шрифт Noto Sans, акценты `#F88A2A` (кнопка) и `#FBC028` (активная точка)
- Свайп или кнопка переключают страницы

После **Начать** открывается гостевой каркас с нижней панелью по макету (кадр поиска `1:16160`). Экран входа не показывается: авторизация будет на отдельных действиях, не как заглушка перед приложением.

**Нижняя панель**

| Вкладка | Экран |
| --- | --- |
| Поиск | Пустое состояние, пока не указан город или фильтр; выдача по заглушкам (Москва / Казань / Санкт-Петербург) |
| Брони | Сегменты «Текущие» / «Прошлые», карточки-заглушки |
| Избранное | Список избранного и пустое состояние |
| Чаты | Список диалогов-заглушек |
| Профиль | Имя, телефон, пункты меню (вход не вытесняет каркас) |

- Кремовый фон панели `#FFFBF2`, активный акцент `#F88A2A`
- Поиск: оранжевая шапка, поле «Хочу снять жилье в...», кнопка **Найти отель**
- Иконки фильтра/карты — `images/search/`

**Прочее**
- Тема `AppTheme`, edge-to-edge, скрыт debug-banner
- Нативный Android splash — белый фон, подпись приложения GlobalStay
- Виджет-тесты: сплэш → онбординг → вкладки, поиск по городу, чат, профиль

Рабочая ветка: `dev/taps`.

## Запуск

SDK: `~/development/flutter`. Перед командами:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

### Linux desktop

Для `flutter run` на Linux нужны CMake, Clang, Ninja и GTK 3:

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev mesa-utils
flutter doctor    # Linux toolchain должен быть ✓
flutter pub get
flutter run -d linux
```

### Android (эмулятор Pixel)

AVD `pixel` (Android 16 / Play Store). После загрузки обычно виден как `emulator-5554`.

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

# 1. Зависимости проекта
flutter pub get

# 2. Запустить AVD и дождаться Android
flutter emulators --launch pixel
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
  sleep 2
done

# 3. Собрать debug и поставить на эмулятор
flutter devices                 # должен быть emulator-5554
flutter run -d emulator-5554
```

В терминале `flutter run`: `r` — hot reload, `R` — hot restart, `q` — выход.

Перед выключением компьютера сначала `q` в `flutter run`, затем погасить AVD:

```bash
adb devices                 # должен быть emulator-5554
adb emu kill                # штатно выключить эмулятор
adb devices                 # список пустой — можно выключать ПК
```

Если `adb emu kill` не помог (qemu всё ещё в `ps`):

```bash
pkill -f 'qemu-system-x86_64 -avd pixel'
pgrep -a qemu || echo "эмулятор выключен"
```

Полный список команд — в [`docs/doc.md`](docs/doc.md). Продуктовая спецификация — в [`docs/technical spec.md`](docs/technical%20spec.md).

## Структура проекта

```
Booking/
├── lib/
│   ├── main.dart                      # BookingApp, точка входа
│   ├── theme/
│   │   └── app_theme.dart             # цвета, Noto Sans, кнопка
│   ├── shell/
│   │   └── main_shell.dart            # нижняя панель, IndexedStack вкладок
│   └── screens/
│       ├── splash_screen.dart         # сплэш
│       ├── onboarding_screen.dart     # карусель → MainShell
│       ├── search/search_screen.dart
│       ├── bookings/bookings_screen.dart
│       ├── favorites/favorites_screen.dart
│       ├── chat/chat_screen.dart
│       └── profile/profile_screen.dart
├── images/
│   ├── logo.svg                       # логотип сплэша
│   ├── splash.png                     # референс сплэша из макета
│   ├── search/                        # empty-state и иконки шапки поиска
│   ├── chat/                          # превью диалогов
│   ├── profile/avatar.png
│   └── onbordins.v1/
│       ├── 01-find-housing.png
│       ├── 02-book-confidently.png
│       └── 03-travel-without-borders.png
├── fonts/
│   ├── NotoSans-Regular.ttf
│   └── NotoSans-Bold.ttf
├── test/
│   ├── widget_test.dart
│   ├── search_screen_test.dart
│   ├── chat_screen_test.dart
│   └── profile_screen_test.dart
├── docs/
│   ├── doc.md                         # команды Flutter / Android
│   └── technical spec.md              # ТЗ клиента
├── android/  ios/  linux/  macos/  web/  windows/
├── pubspec.yaml
└── README.md
```

Каркас платформ — стандартный `flutter create`. Данные вкладок — заглушки; бэкенд поиска, бронирования и авторизации ещё не подключён.
