# GlobalStay (Booking)

Клиентское Flutter-приложение для бронирования жилья. Макет: [Figma — Booking](https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking).

Бэкенд — PocketBase на `https://pb.booking.vallome.ru`. Каталог опубликованных объявлений и брони гостя клиент читает и пишет по API; избранное и чаты ещё не подключены. Вход по email — письмо с кнопкой **Авторизоваться** (под капотом OTP коллекции `users`, без ввода кода).

## Что сделано

Сплэш и онбординг (вариант 1) проверены на эмуляторе **Pixel**. После **Начать** или свайпа за последнюю страницу открывается вкладка Email. Гостевая оболочка — после успешного входа.

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
- Свайп или кнопка переключают страницы; свайп за третий экран тоже открывает авторизацию

**Оболочка (`MainShell`)**

| Вкладка | Состояние |
| --- | --- |
| Поиск | Живой каталог из PocketBase, карта Mapbox, фильтры, карточка объявления |
| Брони | Живые записи коллекции `bookings` (`fetchMine`). «Предстоящие» — карточки по макету Figma `1:11949` (фото, название, даты `ДД.ММ.ГГГГ`, гости, чип статуса из поля `bookings.status`). Клик открывает карточку брони: ожидание хозяина `1:13403`, предоплата `1:13173`, подтверждено `1:12259`. «Архив» — `completed` / `cancelled` (`1:12013`); клик по отменённой — `1:12491`, по прошедшей без отзыва — `1:12718`, с отзывом — `1:12946`. Пустой таб — иллюстрация и текст по макету Figma `1:11894`. После create/patch список перечитывается (`BookingsRepositoryScope.listVersion` + повторный fetch, когда вкладка снова видна) |
| Избранное | UI карточек, список пустой (серверное избранное не читается) |
| Чаты | Макет списка на локальных заглушках |
| Профиль | Имя и аватар сессии; личные данные, уведомления, выход и удаление аккаунта работают; поддержка пока заглушка |

**Поиск и карточка**
- Публичные `listings` со `status = published`, хозяин через `expand=host`
- Рейтинг и число отзывов на карточке поиска и деталке — из коллекции `reviews` (`kind = listing`); если записей нет или запрос не удался, берутся денорм-поля `listings.rating` / `listings.reviews_count`
- Поиск по городу, датам и гостям (Mapbox Geocoding), фильтры: тип жилья, цена, удобства, доп. опции
- Форма «Снять жилье» — отдельный экран (`MaterialPageRoute`), не modal-sheet: так поле города принимает клавиатуру на Android 16
- Чипы под шапкой — только параметры этой формы (город, даты, гости)
- Список и карта с пинами; фото с файлового API PocketBase (`ListingImage`)
- Деталка объявления свёрстана по макету Figma `1:10782` (герой, удобства, отзывы, хозяин, другие объявления, sticky **Забронировать**). «Смотреть все» в блоке отзывов открывает полный список Figma `1:11227`; «Смотреть все» у объявлений хозяина открывает список объявлений хозяина; **Забронировать** открывает шит «Даты проживания» (Figma `1:11757`), после **Сохранить** — шит «Гости» (Figma `1:11776`), после ещё одного **Сохранить** — шит подтверждения «Бронирование» (Figma `1:11497`). Даты и гости до подтверждения живут только на устройстве (`SharedPreferences`, ключ `booking_draft`: listing id + заезд + выезд + adults/children/pets). **Вернуться** на карточке подтверждения сбрасывает весь локальный черновик (`BookingDraftStore.clear()`). **Забронировать** на этой карточке пишет запись в PocketBase `bookings` (`BookingsRepository.create`; createRule требует `status = pending_host`, чип на вкладке «Брони» берётся из статуса вернувшейся/прочитанной записи, не захардкожен на карточке) и затем очищает черновик; без сессии показывается «Войдите, чтобы забронировать жилье», запись не создаётся. Новая бронь сразу попадает в Брони → **Предстоящие** (`pending_host` — upcoming). Сразу после успешного create поверх шита всплывает модалка Figma `1:11832` («Запрос на бронирование отправлен» / «Ожидайте подтверждение… 12 часов» / **Ок**) — центрированная карточка 16px на барьере `#525353`, не snackbar и не bottom sheet. **Ок** закрывает попап и шит подтверждения. Параллельно клиент пишет строку в PocketBase `notifications` (title/body из макета, `user` = сессия, `booking` + `listing` с созданной брони); если create уведомления отклонят правила, попап всё равно показывается. Тот же текст уходит в Профиль → **Уведомления** (Figma `1:11396`). Правила календаря те же, что у поиска (`stayDatePickerBounds` / `completeSearchStayDates`); степперы гостей — как в поиске (взрослые от 1, дети и животные от 0, потолок 16), `pets_allowed` объявления блокирует животных.
- Сердце избранного — глиф Iconly (`FavoriteHeartButton`); состояние локальное, вкладка «Избранное» с PocketBase не связана
- Блок **Владелец** общий (`ListingHostSection`) на деталке жилья и на всех карточках брони: фото, имя (`first_name` + `last_name`), рейтинг, чат-заглушка, бейджи. «Верификация пройдена» читает `users.verified_host`, не системный email-`verified`. «N лет сдает жилье» — `users.years_hosting`

**Карточка брони**
- Адрес (подчёркнутый) → модалка `1:13629` → «Да, смотреть» открывает карту Mapbox с пином
- **Отменить** → `1:13635`; «Да, отменить» пишет `status = cancelled` и `cancel_reason = guest`. Бронь сразу в Архив с чипом «отменено». Ключ БД `cancel_requested` остаётся, в гостевом UI его нет
- **Изменить бронирование** → шит `1:11560` (даты и гости). «Отправить» пишет `change_requested` и показывает окно `1:11840`. На списке тот же чип, что у `pending_host`: «ожидание подтверждения от владельца» (в макете Предстоящих отдельного чипа для правок нет)
- **Пожаловаться** → экран `1:11353`: бронь / жильё / владелец. Ticket в коллекцию `tickets`. «Написать владельцу» — заглушка чата
- Прошедшая без отзыва: кнопка «Оставить отзыв» пишет `reviews` (`kind = listing`). После отправки сразу шаблон «отзыв оставлен»
- «Внести предоплату» на карточке `awaiting_prepayment` пока заглушка

**Личные данные**
- Профиль → **Личные данные** (макет Figma `1:14538`)
- Форма подставляет текущие `first_name`, `last_name`, `birthdate`, `email` и `avatar` сессии
- **Сохранить** пишет только запись текущего пользователя в PocketBase `users` (id из auth store, тело запроса через SDK, без склейки SQL/filter)
- Если email изменился (без учёта регистра и пробелов по краям), **Сохранить** сначала показывает модалку в стиле выхода: **Нет** или тап вне карточки отменяет сохранение и возвращает в поле текущий email сессии; **Да** сначала проверяет уникальность нового адреса (`POST /api/vallome/change-email`): **один пользователь — один email**, занятый в `users` или уже заявленный другим гостем адрес даёт «Этот email уже занят», сессия остаётся, имя/фото не пишутся. Свободный адрес ставит заявку, затем клиент пишет имя/дату/фото и выходит на авторизацию с подставленным новым адресом. Почта записи меняется только после magic-link **на новый ящик**. Если к этому моменту адрес уже занят, страница ссылки показывает «Этот email уже занят», запись не трогается. Вход по старому адресу снимает заявку.
- Если email тот же, сохранение как раньше: без модалки, возврат на вкладку «Профиль»
- После сохранения имя и аватар на вкладке «Профиль» берутся из обновлённой сессии
- Дата рождения — `ДД.ММ.ГГГГ`, 18+; младше 18 лет остаются с `limited_browse`
- Фото — тот же запрос доступа и `image_picker`, что и при регистрации; грант помнится, круг кропа можно двигать по снимку

**Уведомления**
- Профиль → **Уведомления** (макет Figma `1:11396`): полноэкранный список, как «Личные данные», не bottom sheet. Карточка с кремовой заливкой, обводкой и красной точкой непрочитанного (ассет `images/profile/unread-dot-7.svg`, 7×7)
- Записи читаются из PocketBase `notifications` (`NotificationsRepository.fetchMine`, `user =` текущая сессия через `pbFilter`). Бейдж в меню — живой unread count, 0 не рисуется (больше не заглушка «2»)
- После бронирования в инбоксе тот же заголовок, что у попапа `1:11832`; в теле подставляется название жилья, если оно есть. Макет `1:11396` показывает чужой сценарий («Владелец подтвердил вашу бронь» / предоплата) — это не этот шаг

**Авторизация**
- Email: свой адрес → письмо от **vallome.booking** с кнопкой **Авторизоваться**. Поля кода нет. Запись в `users` появляется **только после** клика по ссылке, не в момент запроса письма. Новому гостю хук сразу ставит обязательный `account_status = active` — без этого PocketBase отклоняет `save` и страница ссылки ошибочно писала «устарела». После клика вернитесь в приложение: экран ожидания сам подхватывает сессию (опрос `/api/vallome/magic-wait`). Ссылки `vallome-booking://` на Ubuntu открывают магазин приложений — на компьютере ими не пользоваться
- Сессия пишется в `SharedPreferences` (`pb_auth`) и переживает перезапуск: сплэш сразу открывает оболочку или дорегистрацию
- Телефон пока заглушка: тап по полю подставляет `+79999999999`, код `77777`
- Чекбокс пользовательского соглашения обязателен до **Далее**
- Новый пользователь заполняет имя, фамилию, дату рождения (18+) и фото профиля
- Доступ к фото / камере — in-app лист в стиле iOS (Figma) плюс системные запросы `permission_handler` на галерею и камеру. Согласие (ограниченный или полный доступ) пишется в `SharedPreferences` (`photo_access_granted`, рядом с `pb_auth`): следующий тап по аватару лист не показывает. «Не предоставлять» или отказ ОС не запоминаются — спрашиваем снова. `isDenied` больше не считается грантом. `photo_manager` не используем: его Kotlin-плагин надолго вешает Gradle
- Кроп аватара — чёрный экран с кругом, который можно перетащить по фото; **Сохранить** пишет только круглую область под кругом, не исходный файл
- Образец фото в галерею эмулятора: `bash scripts/push_emulator_gallery.sh`

**Профиль: выход и удаление аккаунта**
- **Выйти из аккаунта** — модалка «Выйти из аккаунта?» (Figma `1:14582`). **Нет** и тап вне окна закрывают диалог и оставляют сессию. **Да** сбрасывает `pb_auth` и открывает экран авторизации
- **Удалить аккаунт** — такая же модалка «Удалить аккаунт?» (Figma `1:14585`). **Нет** / тап вне окна **не** удаляет запись. **Да** вызывает `DELETE` коллекции `users` через SDK PocketBase: id берётся только из текущей сессии (`authStore.record.id`), без склейки filter-строк. Правило сервера: `id = @request.auth.id`
- После успешного удаления (или если запись уже 404) локальная сессия очищается, открывается **Авторизация**. Ошибка сети / отказа сервера показывает сообщение, сессия сохраняется

**Ещё не сделано:** настоящий OTP по телефону, оплата предоплаты и ответ хозяина, серверные избранное и чаты (чат с хозяином с карточки брони — заглушка).

**Прочее**
- Тема `AppTheme`, locale `ru_RU`, edge-to-edge, скрыт debug-banner
- Android overscroll stretch (`StretchingOverscrollIndicator`) отключён глобально: `MaterialApp.scrollBehavior` = `AppScrollBehavior` (`ClampingScrollPhysics`, индикатор не строится)
- Нативный Android splash — белый фон, подпись GlobalStay; в манифесте `INTERNET` и `windowSoftInputMode=adjustResize` (клавиатура не ломает экран авторизации)
- Виджет-тесты: сплэш → онбординг → auth/magic-link/регистрация, доступ к фото (лист один раз после гранта, снова после отказа), кроп-круг, поиск, фильтры, деталка, брони (карточка, адрес/карта, отмена, изменение, жалобы, архив, отзыв), маппинг хозяина (`verified_host`), профиль (выход и удаление аккаунта), личные данные и подтверждение смены email (репозиторий подменяется фикстурой)

## Бэкенд

Клиент ходит на `https://pb.booking.vallome.ru` (`PocketBaseConfig.url`). Другой хост:

```bash
flutter run -d linux --dart-define=POCKETBASE_URL=https://example.com
```

Схема коллекций — [`pb_schema.json`](pb_schema.json) и [`docs/pocketbase-schema.md`](docs/pocketbase-schema.md). У `users` бейдж хозяина — поле `verified_host`, его нельзя путать с системным `verified` (подтверждение email). Сервер (Caddy, TLS) — [`docs/pocketbase-server.md`](docs/pocketbase-server.md).

**Запросы к PocketBase.** Клиент не склеивает пользовательские строки в `filter`. Значения подставляются через `pbFilter` (`lib/data/pocketbase_filter.dart`) с плейсхолдерами `{:name}` — тот же синтаксис, что у `PocketBase.filter` в Dart SDK. Имена коллекций только из `PbCollection` (`users`, `listings`, `bookings`, `notifications`, `tickets`, `reviews`), не из ввода. Пример:

```dart
final filter = pbFilter(
  'status = "published" && host = {:hostId} && id != {:exceptId}',
  {'hostId': hostId, 'exceptId': exceptId},
);
await pb.collection(PbCollection.listings).getFullList(filter: filter);
```

Хук `bookings_overlap.pb.js` биндит listing/даты/id в `findRecordsByFilter(..., {:placeholder})`. Сид-скрипты используют тот же приём (`pb_filter` в `scripts/seed_listings.py`). Правила API по-прежнему отдают гостю только свои брони (`guest` / `host` = текущий пользователь).

Каталог и схему для разработки наполняют идемпотентные скрипты (нужны `POCKETBASE_SU` и `POCKETBASE_SU_PASSWORD` в `.env.local`, шаблон — [`.env.example`](.env.example)):

```bash
python3 scripts/seed_listings.py
python3 scripts/seed_listings.py --reset   # удалить сид-объявления и создать заново
python3 scripts/enable_email_otp.py        # magic-link (OTP) на email + SMTP, отправитель vallome.booking
python3 scripts/ensure_users.py            # доменные поля users + бэкафил хозяев (бейдж = verified_host, не системный verified)
python3 scripts/ensure_bookings.py         # коллекция bookings, правила и индексы
python3 scripts/ensure_notifications.py    # коллекция notifications (инбокс), createRule = текущий user
python3 scripts/ensure_reviews.py          # коллекция reviews, публичные отзывы на жильё
python3 scripts/seed_reviews.py            # демо-отзывы на опубликованные объявления + денорм rating
python3 scripts/seed_reviews.py --reset    # удалить сид-отзывы и создать заново
bash scripts/push_emulator_gallery.sh      # фото профиля в галерею эмулятора
```

Хуки PocketBase (`pb_hooks/`) на сервере в `/opt/pocketbase/pb_hooks` с `--hooksDir=/opt/pocketbase/pb_hooks`. Новый файл (например `change_email.pb.js`):

```bash
scp pb_hooks/change_email.pb.js root@159.194.252.80:/tmp/change_email.pb.js
ssh root@159.194.252.80 'install -o pocketbase -g pocketbase -m 644 /tmp/change_email.pb.js /opt/pocketbase/pb_hooks/change_email.pb.js && systemctl restart pocketbase'
```

| Файл | Зачем |
| --- | --- |
| `otp_signup.pb.js` | Не создаёт `users` на запрос письма |
| `magic_link.pb.js` | `POST /api/vallome/magic-request` шлёт письмо без записи в БД; пользователь создаётся при клике «Авторизоваться» с `account_status = active`; `/api/vallome/magic-auth` и `/api/vallome/magic-wait`; подтверждённая заявка на смену email применяется здесь |
| `change_email.pb.js` | `POST /api/vallome/change-email`: заявка на смену email текущего пользователя; адрес применяется только после magic-link на новый ящик |
| `bookings_overlap.pb.js` | Запрет пересечения дат на занятом жилье |

Отдельного хука `/api/vallome/` для уведомлений нет: клиент пишет в `notifications` сам, если `createRule` пускает `@request.body.user = @request.auth.id` (как у `bookings`). Коллекцию поднимает `scripts/ensure_notifications.py`.

Пять опубликованных объявлений (Москва, Казань, Санкт-Петербург) и один черновик. Пароль сид-пользователей каталога: `SeedPass123!`.

Вход в приложении: свой email → письмо → **Авторизоваться** → вернуться в приложение. Телефон пока заглушка `+79999999999` / код `77777`.

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
flutter test test/pocketbase_filter_test.dart   # безопасная сборка PocketBase filter
```

Полный список команд — в [`docs/doc.md`](docs/doc.md). Продуктовая спецификация — в [`docs/technical spec.md`](docs/technical%20spec.md).

## Структура проекта

```
Booking/
├── lib/
│   ├── main.dart
│   ├── theme/app_theme.dart
│   ├── config/                    # PocketBase URL, Mapbox
│   ├── data/                      # клиент PB, auth, listings, bookings, tickets, reviews, notifications, pbFilter
│   ├── widgets/                   # ListingImage, ListingHostSection, FavoriteHeartButton, confirm dialog
│   ├── shell/main_shell.dart      # нижняя панель
│   └── screens/
│       ├── splash_screen.dart
│       ├── onboarding_screen.dart
│       ├── auth/                  # email magic-link, phone stub, регистрация, фото
│       ├── search/                # каталог, карта, фильтры, запрос
│       ├── listing/               # деталка, даты, гости, подтверждение брони, попап 1:11832, объявления хозяина
│       ├── bookings/              # список, карточки статусов, адрес/карта, отмена, изменение, жалобы, архив, отзыв
│       ├── favorites/
│       ├── chat/
│       └── profile/               # меню, личные данные, уведомления 1:11396, выход
├── pb_hooks/                      # JS-хуки PocketBase (копировать на VPS; без change_email.pb.js смена почты в профиле не работает)
├── scripts/
│   ├── seed_listings.py
│   ├── seed_reviews.py
│   ├── enable_email_otp.py
│   ├── ensure_users.py
│   ├── ensure_bookings.py
│   ├── ensure_notifications.py
│   ├── ensure_reviews.py
│   └── push_emulator_gallery.sh
├── test/
│   ├── fixtures/demo_listings.dart
│   ├── fixtures/fake_auth.dart
│   ├── fixtures/fake_bookings.dart
│   ├── fixtures/fake_notifications.dart
│   ├── widget_test.dart
│   ├── pocketbase_filter_test.dart
│   ├── auth_screen_test.dart
│   ├── otp_register_test.dart
│   ├── photo_access_test.dart
│   ├── search_screen_test.dart
│   ├── listing_detail_screen_test.dart
│   ├── booking_confirmation_sheet_test.dart
│   ├── notifications_test.dart
│   ├── bookings_screen_test.dart
│   ├── profile_screen_test.dart
│   └── personal_data_screen_test.dart
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
