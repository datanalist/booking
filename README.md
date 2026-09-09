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

После **Начать** открывается заглушка «Авторизация» (экран входа ещё не свёрстан).

**Прочее**
- Тема `AppTheme`, edge-to-edge, скрыт debug-banner
- Нативный Android splash — белый фон, подпись приложения GlobalStay
- Виджет-тесты: сплэш → онбординг → переход по страницам

## Запуск

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"

flutter pub get
flutter emulators --launch pixel
flutter run -d emulator-5554
```

Полный список команд — в [`docs/doc.md`](docs/doc.md). Продуктовая спецификация — в [`docs/technical spec.md`](docs/technical%20spec.md).

## Структура проекта

```
Booking/
├── lib/
│   ├── main.dart                      # BookingApp, точка входа
│   ├── theme/
│   │   └── app_theme.dart             # цвета, Noto Sans, кнопка
│   └── screens/
│       ├── splash_screen.dart         # сплэш
│       └── onboarding_screen.dart     # карусель + заглушка авторизации
├── images/
│   ├── logo.svg                       # логотип сплэша
│   ├── splash.png                     # референс сплэша из макета
│   └── onbordins.v1/
│       ├── 01-find-housing.png
│       ├── 02-book-confidently.png
│       └── 03-travel-without-borders.png
├── fonts/
│   ├── NotoSans-Regular.ttf
│   └── NotoSans-Bold.ttf
├── test/
│   └── widget_test.dart
├── docs/
│   ├── doc.md                         # команды Flutter / Android
│   └── technical spec.md              # ТЗ клиента
├── android/  ios/  linux/  macos/  web/  windows/
├── pubspec.yaml
└── README.md
```

Каркас платформ — стандартный `flutter create`. Бизнес-логика поиска, бронирования и авторизации пока не реализована.
