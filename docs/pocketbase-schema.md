# Схема данных PocketBase

Бэкенд — PocketBase (`https://pb.booking.vallome.ru`, см. [pocketbase-server.md](pocketbase-server.md)). Один auth-`users` на гостя, хозяина и сотрудника: иначе бронь, чат и отзыв не связать (у PB нет полиморфных relation). Деньги — `number` в рублях, не копейки. У каждой коллекции системные `id`, `created`, `updated` — ниже не повторяются. Значения `select`-статусов — ключи API; подписи чипов мапятся в клиенте.

Источник: `docs/technical spec.md` и экраны ветки `dev/taps`. Пометки **ТЗ** / **экран** / **интерпретация** — только там, где это важно.

## Коллекции

### `users` (auth)

Встроенные: `email` (не required — гость может пропустить анкету, **ТЗ**), `password`, `verified`. `emailVisibility` — системное PB, не доменное поле.

- `phone`: text, unique — вход гостя / контакт хозяина
- `first_name`, `last_name`: text — анкета бронирования (**ТЗ**); на `ProfileScreen` одна строка имени
- `avatar`: file(1) — профиль и карточка хозяина
- `birthdate`: date — возраст 18+ (**ТЗ**; анкета после email OTP)
- `limited_browse`: bool, default false — гость без полной анкеты (**экран**)
- `bio`: text — «информация о владельце»
- `roles`: select multiple `[guest, host, staff]` — три кабинета ТЗ, не три коллекции (**интерпретация**); для OTP-signup не required
- `account_status`: select `[active, pending, blocked, rejected]`, required, default `active` — имена под сценарии ТЗ: заявка сотрудника, принять/отклонить, блок, бан хозяина (**интерпретация**)
- `staff_tasks`: text — «задачи сотрудника» есть в ТЗ, словаря значений нет
- `verified_host`: bool, default false — бейдж «Верификация пройдена» / `ListingHost.verified` (**экран**)
- `years_hosting`: number — `ListingHost.years` / «N лет сдает жилье» (`yearsHostingLabel`) (**экран**, в ТЗ нет). Храним число как на карточке, не дату
- `rating`, `reviews_count`: number — денорм хозяина для карточек
- `balance`: number, default 0 — сумма к выводу (**ТЗ**)
- `fcm_token`: text — пуш (**интерпретация**; поля в UI нет)

Вход гостя по email — письмо с кнопкой (TTL 600 с, SMTP). Клиент вызывает `POST /api/vallome/magic-request`: письмо уходит **без** записи в `users`. Строка в `users` создаётся только когда гость подтверждает ссылку (`/api/vallome/magic-auth`). Публичный `createRule` у `users` закрыт (только админ / хук). Поля `roles` / `name` / `first_name` / `last_name` не required. Включить OTP+SMTP: `python3 scripts/enable_email_otp.py`.

### `listings`

Публично только `published`. Правка хозяином → снова `pending` (**ТЗ**).

- `host`: relation → `users`, required
- `title`, `city` (index), `address`: text, required
- `geo`: geoPoint — маркеры карты / `SearchListing.latitude|longitude` (**интерпретация**)
- `housing_type`: select `[Квартира, Дом, Комната, Отель]`, required — `SearchFiltersSheet._housingTypes` (**экран**)
- `placement_type`: text — имя «Тип размещения» есть в ТЗ, экрана нет; **значения не зафиксированы**, select-словаря нет
- `photos`: file, multiple, required; минимум 6 — хук (**ТЗ**); потолка нет
- `description`: editor, required
- `amenities`: select multiple `[Wifi, Телевизор, Кондиционер, Обогреватель, Фен, Утюг, Кухня, Стиральная машина, Посуда]` — `SearchFiltersSheet._amenities`
- `extras`: select multiple `[Завтраки, Бассейн, Камин, Разрешено курение, Спортзал, Самостоятельное заселение, Сауна, Парковка]` — `SearchFiltersSheet._extras`
- `max_guests`: number, required
- `pets_allowed`, `cancellation_allowed`: bool, required
- `access_info`, `house_rules`, `extra_info`: text — инструкции / правила / доп. информация
- `check_in_time`, `check_out_time`: text `HH:mm`, required
- `price_night` (index), `price_14`, `price_28`: number, required — сутки / от 14 / от 28
- `status`: select `[draft, pending, published, rejected, archived]`, required, index — `draft`: создать, потом отправить на модерацию (**интерпретация**)
- `reject_reason`: text — причина отказа модератора
- `rating`, `reviews_count`: number — денорм для карточек поиска/деталки

### `listing_blocks`

Календарь хозяина: «редактировать занятость» (**ТЗ**; в Flutter нет).

- `listing`: relation → `listings`, required
- `start`, `end`: date, required
- индекс `(listing, start)` — выборка занятости по объекту

### `favorites`

- `user`: relation → `users`, required
- `listing`: relation → `listings`, required
- unique `(user, listing)` — одно избранное на пару

Гость читает, создаёт и удаляет только свои записи (`user` = текущая сессия). Правки записи нет: сердце снова добавляет пару. Коллекцию поднимает `scripts/ensure_favorites.py`.

### `bookings`

- `listing`, `guest`, `host`: relation → `listings` / `users`, required
- `check_in`, `check_out`: date, required
- `adults`, `children`, `pets`: number
- `guest_note`: text — «написать владельцу» при запросе
- `total`, `prepay`, `remainder`, `commission`, `host_amount`: number — предоплата / остаток хозяину / комиссия (**ТЗ**; имена полей — **интерпретация**)
- `prepaid_at`: date — факт оплаты предоплаты; хозяин видит, оплатил ли гость (**ТЗ**)
- `status`: select `[pending_host, awaiting_prepayment, confirmed, completed, cancel_requested, change_requested, cancelled]`, required — **без `rejected`**: отказ хозяина = `cancelled` + причина (**ТЗ**: не реагирует или отклоняет → автоотмена)
- `cancel_reason`: select `[guest, host, host_timeout, prepay_timeout]` — **без `admin`**: админ в ТЗ возвращает деньги из поддержки, бронь не отменяет
- `host_respond_until`, `prepay_until`: date — дважды «12 часов» (**ТЗ**)
- `requested_check_in`, `requested_check_out`: date — запрос смены сроков

Чипы `_BookingStatus` (**экран**): `pending_host` / `awaiting_prepayment` / `confirmed` / `cancelled`.  
«Прошлые» = `completed` + `cancelled`.  
Занятость дат для поиска и карты = статусы вкладки «Предстоящие»: `pending_host` ∪ `awaiting_prepayment` ∪ `confirmed` ∪ `change_requested`, плюс `listing_blocks`. `completed`, `cancelled` и `cancel_requested` даты не занимают.

Сумма возврата — у `tickets`, не здесь.

### `reviews`

После аренды: гость → жильё, хозяин → клиент (**ТЗ**).

- `booking`: relation → `bookings`, required
- `author`: relation → `users`, required
- `listing`: relation → `listings`
- `subject`: relation → `users` — о ком отзыв (гость или хозяин)
- `kind`: select `[listing, guest]`, required
- `rating`: number 1–5, required
- `comment`: text
- unique `(booking, kind)` — не больше одного отзыва каждого вида на бронь

### `chats`

ТЗ: каждый чат привязан к жилью; пункт «Написать в поддержку» даёт второй вид (**интерпретация**).

- `kind`: select `[listing, support]`, required
- `listing`: relation → `listings`
- `booking`: relation → `bookings`
- `guest`: relation → `users`, required
- `host`: relation → `users`
- `staff`: relation → `users` — админ в чате (**ТЗ**; на превью строка «…, Админ»)
- `last_message`: text; `last_message_at`: date — превью `_ChatPreview`
- `guest_last_read`, `host_last_read`: date — непрочитанные на списке (**экран**)
- unique `(listing, guest)` при `kind=listing` — один тред на пару (хук `pb_hooks/chats_messages.pb.js`)

Коллекцию поднимает `scripts/ensure_chats.py`. Участники (guest / host / staff) читают и обновляют свои чаты; создать listing-чат может только `guest` = текущая сессия.

### `messages`

- `chat`: relation → `chats`, required
- `author`: relation → `users`, required
- `text`: text
- `images`: file, multiple
- `files`: file, multiple — файлы шлёт сотрудник (**ТЗ**)

Коллекцию поднимает `scripts/ensure_messages.py` (после `ensure_chats.py`). Список/создание только для участников чата. Хук обновляет `chats.last_message` / `last_message_at` после нового сообщения.

### `tickets`

Обращения и жалобы в поддержку. Статуса обращения нет — поле не заводить.

- `author`: relation → `users`, required
- `type`: select `[support, listing, host, booking]`, required
- `listing`: relation → `listings`
- `host`: relation → `users`
- `booking`: relation → `bookings`
- `chat`: relation → `chats` — админ подключается к чату брони
- `text`: text, required
- `photos`: file, multiple
- `assignee`: relation → `users` — кто из сотрудников ведёт
- `refund_amount`: number — «указывает сумму, которую вернуть» (**ТЗ**)

### `notifications`

Инбокс / пуш (пункт меню с бейджем). Словаря `type` нет — не заводить.

- `user`: relation → `users`, required, index
- `title`: text, required
- `body`: text
- `read`: bool, default false
- `booking`: relation → `bookings`
- `listing`: relation → `listings`
- `chat`: relation → `chats`

### `payouts`

«Запросить вывод»; баланс после окончания аренды минус комиссия (**ТЗ**). Отклонения вывода нет.

- `host`: relation → `users`, required
- `amount`: number, required
- `status`: select `[requested, paid]`, required — **без `rejected`**

## Связи

```
users ──1:*── listings.host
users ──1:*── favorites.user
users ──1:*── bookings.guest | bookings.host
users ──1:*── reviews.author | reviews.subject
users ──1:*── chats.guest | chats.host | chats.staff
users ──1:*── tickets.author | tickets.assignee | tickets.host
users ──1:*── notifications.user
users ──1:*── payouts.host

listings ──1:*── listing_blocks
listings ──1:*── favorites
listings ──1:*── bookings
listings ──1:*── reviews
listings ──1:*── chats          (kind=listing)

bookings ──1:*── reviews        unique (booking, kind)
bookings ──*──1── chats
bookings ──*──1── tickets

chats    ──1:*── messages
chats    ──*──1── tickets
```

Занятость объекта = блоки календаря ∪ брони в статусах ожидания/подтверждения/запроса отмены или смены дат.

## Сознательно не вынесено

Отдельные коллекции `hosts` / `staff`, справочники городов и удобств, отдельная коллекция OTP, ledger, история статусов, коллекция фото, настройки комиссии.

Убрано после ревью первой схемы: enum `placement_type` (целиком / комната / койко-место), потолок `photos` ~20, словарь `staff_tasks`, доменное описание `emailVisibility`, `bookings.status = rejected`, `cancel_reason = admin`, `bookings.refund_amount`, `tickets.status`, `notifications.type`, `payouts.status = rejected`.
