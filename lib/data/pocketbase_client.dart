import 'package:pocketbase/pocketbase.dart';

import '../config/pocketbase_config.dart';

/// Общий клиент PocketBase для приложения.
final PocketBase pocketBase = PocketBase(PocketBaseConfig.url);
