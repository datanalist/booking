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
