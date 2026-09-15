/// Публичный URL PocketBase. Секреты сюда не кладём.
/// Переопределение: `--dart-define=POCKETBASE_URL=https://...`
abstract final class PocketBaseConfig {
  static const url = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'https://pb.booking.vallome.ru',
  );
}
