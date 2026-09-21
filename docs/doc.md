# Flutter — основные команды

SDK: `~/development/flutter`. Перед работой:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
```

## Среда

```bash
flutter doctor          # проверка SDK, Android, лицензий
flutter devices         # подключенные устройства / эмуляторы
flutter emulators       # список эмуляторов
flutter emulators --launch <id>
flutter emulators --launch pixel   # AVD Pixel (Android 16 / Play Store)
```

## Проект и пакеты

```bash
flutter create .                    # каркас проекта в текущей папке
flutter pub get                     # скачать зависимости
flutter pub add <пакет>             # добавить зависимость
flutter pub add --dev <пакет>       # dev-зависимость
flutter pub upgrade                 # обновить в пределах ограничений
flutter pub outdated                # что можно обновить
flutter clean                       # сбросить сборку и кэш
```

## Запуск и сборка

```bash
flutter run                         # debug на первом устройстве
flutter run -d <id>                 # конкретное устройство
flutter run --release
flutter test
flutter analyze

flutter build apk                   # Android APK
flutter build appbundle             # Android AAB (Play Store)
flutter build web
flutter build linux
```

В терминале `flutter run`: `r` — hot reload, `R` — hot restart, `q` — выход.

## Auth, OTP, галерея эмулятора

```bash
python3 scripts/enable_email_otp.py          # 5-значный email OTP + SMTP
bash scripts/push_emulator_gallery.sh        # images/profile/avatar.png → Pictures
bash scripts/push_emulator_gallery.sh emulator-5554
```

Фото профиля берётся системным picker (`image_picker`), не `photo_manager`. Первая debug-сборка Android может идти несколько минут из‑за Gradle; повторные — быстрее. Если `flutter run` завис на `assembleDebug` без прогресса больше ~5 минут — остановить (`q`) и проверить, не крутится ли лишний Gradle.

## Несколько эмуляторов (разные аккаунты)

Один AVD (`pixel`) второй раз не стартует: каталог `~/.android/avd/pixel.avd` занят. Для двух сессий нужны **два AVD** — у каждого свой диск и свой `pb_auth` в SharedPreferences.

Два `flutter run -d linux` для этого не подходят: общий каталог данных, сессии перезапишут друг друга. Флаг эмулятора `-read-only` на одном `pixel` тоже не для постоянных аккаунтов: логин живёт в оверлее и часто пропадает после выключения.

### Клон AVD

Android Studio → Device Manager → `pixel` → **Duplicate** → имя `pixel2`.

Или из терминала (образ тот же, что у `pixel`; проверьте `sdkmanager --list_installed`):

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$HOME/development/flutter/bin:$PATH"

"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
  -n pixel2 \
  -k "system-images;android-36;google_apis_playstore;x86_64" \
  -d pixel \
  --force
```

В обоих `config.ini` нужно `hw.keyboard=yes`. После правки — холодный старт (`-no-snapshot-load`).

```bash
grep hw.keyboard ~/.android/avd/pixel.avd/config.ini
grep hw.keyboard ~/.android/avd/pixel2.avd/config.ini
```

### Запуск и установка приложения

Порты только чётные (5554, 5556, 5558). `flutter emulators --launch pixel` второй инстанс того же AVD не поднимет.

```bash
emulator -avd pixel  -port 5554 -no-snapshot-load &
emulator -avd pixel2 -port 5556 -no-snapshot-load &

adb wait-for-device
adb devices -l                  # emulator-5554 и emulator-5556
```

Два терминала или сразу все устройства:

```bash
flutter run -d emulator-5554
flutter run -d emulator-5556
# или
flutter run -d all
```

Галерея — всегда с serial, иначе adb возьмёт «текущее» устройство:

```bash
bash scripts/push_emulator_gallery.sh emulator-5554
bash scripts/push_emulator_gallery.sh emulator-5556
```

### Magic-link

Письмо **Авторизоваться** открывать в браузере/Gmail **внутри нужного AVD**. Ссылка `vallome-booking://` с хоста Ubuntu в эмулятор не попадёт.

Если URL уже есть — отправить в конкретный инстанс:

```bash
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d 'vallome-booking://…'
adb -s emulator-5556 shell am start -a android.intent.action.VIEW -d 'vallome-booking://…'
```

Два аккаунта = два разных email. Телефон — заглушка (`+79999999999` / `77777`), для двух пользователей не подходит. Выход на одном AVD не трогает второй; удаление аккаунта на сервере убивает запись `users` для обоих, если email один.

### Остановить конкретный AVD

```bash
adb -s emulator-5554 emu kill
adb -s emulator-5556 emu kill
```

Два Android 16 Play Store одновременно тяжёлые по RAM. Если qemu не стартует — уменьшите `hw.ramSize` в `config.ini` или закройте один инстанс.

## Остановить эмулятор (перед выключением компьютера)

Сначала выйти из `flutter run` (`q` в том терминале). Потом погасить AVD:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

adb devices                 # должен быть emulator-5554 (или несколько emulator-*)
adb emu kill                # штатно выключить «текущий» эмулятор
adb -s emulator-5554 emu kill
adb -s emulator-5556 emu kill
adb devices                 # список пустой — можно выключать ПК
```

Если `adb emu kill` не помог (qemu всё ещё в `ps`):

```bash
pkill -f 'qemu-system-x86_64 -avd pixel'
pkill -f 'qemu-system-x86_64 -avd pixel2'
```

Проверка, что ничего не крутится:

```bash
pgrep -a qemu || echo "эмулятор выключен"
```
