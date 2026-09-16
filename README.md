# GlobalStay (Booking)

Клиентское Flutter-приложение для бронирования жилья. Макет: [Figma — Booking](https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking).

Бэкенд — PocketBase на `https://pb.booking.vallome.ru`. Каталог опубликованных объявлений клиент читает по API; брони, избранное и чаты ещё не подключены. Вход по email ходит в коллекцию `users`.

## Что сделано

Сплэш и онбординг (вариант 1) проверены на эмуляторе **Pixel**. После **Начать** открывается вкладка Email авторизации. Гостевая оболочка — после успешного входа.

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

**Оболочка (`MainShell`)**

| Вкладка | Состояние |
| --- | --- |
| Поиск | Живой каталог из PocketBase, карта Mapbox, фильтры, карточка объявления |
| Брони | UI сегментов «Текущие» / «Прошлые», список пустой |
| Избранное | UI карточек, список пустой (серверное избранное не читается) |
| Чаты | Макет списка на локальных заглушках |
| Профиль | Макет меню на локальных заглушках |

**Поиск и карточка**
- Публичные `listings` со `status = published`, хозяин через `expand=host`
- Поиск по городу, датам и гостям (Mapbox Geocoding), фильтры: тип жилья, цена, удобства, доп. опции
- Форма «Снять жилье» — отдельный экран (`MaterialPageRoute`), не modal-sheet: так поле города принимает клавиатуру на Android 16
- Чипы под шапкой — только параметры этой формы (город, даты, гости)
- Список и карта с пинами; фото с файлового API PocketBase (`ListingImage`)
- Деталка: галерея, удобства, хозяин; «Смотреть все» открывает список объявлений хозяина
- Сердце избранного — глиф Iconly (`FavoriteHeartButton`); состояние локальное, вкладка «Избранное» с PocketBase не связана

**Ещё не сделано:** регистрация / OTP по телефону, создание брони, серверные избранное и чаты.

**Прочее**
- Тема `AppTheme`, locale `ru_RU`, edge-to-edge, скрыт debug-banner
- Нативный Android splash — белый фон, подпись GlobalStay; в манифесте `INTERNET` и `windowSoftInputMode=adjustPan`
- Виджет-тесты: сплэш → онбординг → поиск, фильтры, деталка (репозиторий подменяется фикстурой)

## Бэкенд

Клиент ходит на `https://pb.booking.vallome.ru` (`PocketBaseConfig.url`). Другой хост:

```bash
flutter run -d linux --dart-define=POCKETBASE_URL=https://example.com
```

Схема коллекций — [`pb_schema.json`](pb_schema.json) и [`docs/pocketbase-schema.md`](docs/pocketbase-schema.md). Сервер (Caddy, TLS) — [`docs/pocketbase-server.md`](docs/pocketbase-server.md).

Каталог для разработки наполняет идемпотентный сид (нужны `POCKETBASE_SU` и `POCKETBASE_SU_PASSWORD` в `.env.local`, шаблон — [`.env.example`](.env.example)):

```bash
python3 scripts/seed_listings.py
python3 scripts/seed_listings.py --reset   # удалить сид-объявления и создать заново
python3 scripts/seed_auth_stub.py          # пользователь вкладки Email
```

Пять опубликованных объявлений (Москва, Казань, Санкт-Петербург) и один черновик. Пароль сид-пользователей: `SeedPass123!`.

Сид входа с вкладки Email: `example@mail.com` / `SeedPass123!` (коллекция `users`). Телефон `+79999999999` пишется в ту же запись, только если в схеме есть поле `phone`.

Токен Mapbox — `config/mapbox.env` (не в git) или `--dart-define=MAPBOX_TOKEN=...`. Пример: `config/mapbox.env.example`.

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

Чтобы печатать с клавиатуры компьютера, в `~/.android/avd/pixel.avd/config.ini` должно быть `hw.keyboard=yes`. Если меняли значение — холодная загрузка (`emulator -avd pixel -no-snapshot-load`), иначе снимок поднимет старый `hw.keyboard=no`. Кликните окно эмулятора, затем поле «Город или адрес».

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

### Тесты

```bash
flutter test
```

Полный список команд — в [`docs/doc.md`](docs/doc.md). Продуктовая спецификация — в [`docs/technical spec.md`](docs/technical%20spec.md).

## Структура проекта

```
Booking/
├── lib/
│   ├── main.dart
│   ├── theme/app_theme.dart
│   ├── config/                    # PocketBase URL, Mapbox
│   ├── data/                      # клиент PB, ListingsRepository
│   ├── widgets/                   # ListingImage, FavoriteHeartButton
│   ├── shell/main_shell.dart      # нижняя панель
│   └── screens/
│       ├── splash_screen.dart
│       ├── onboarding_screen.dart
│       ├── search/                # каталог, карта, фильтры, запрос
│       ├── listing/               # деталка и список объявлений хозяина
│       ├── bookings/
│       ├── favorites/
│       ├── chat/
│       └── profile/
├── scripts/seed_listings.py
├── test/
│   ├── fixtures/demo_listings.dart
│   ├── widget_test.dart
│   ├── search_screen_test.dart
│   └── listing_detail_screen_test.dart
├── images/
├── fonts/
├── docs/
│   ├── doc.md
│   ├── technical spec.md
│   ├── pocketbase-schema.md
│   └── pocketbase-server.md
├── pb_schema.json
├── pubspec.yaml
└── README.md
```
