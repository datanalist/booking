import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/mapbox_config.dart';
import 'data/auth_link_listener.dart';
import 'data/auth_repository.dart';
import 'data/pocketbase_client.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPocketBase();
  await AuthRepositoryScope.instance.restoreSession();
  await AuthLinkListener.instance.handleInitialLink();
  await MapboxConfig.initialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const BookingApp());
}

class BookingApp extends StatefulWidget {
  const BookingApp({super.key});

  @override
  State<BookingApp> createState() => _BookingAppState();
}

class _BookingAppState extends State<BookingApp> {
  @override
  void initState() {
    super.initState();
    AuthLinkListener.instance.listenWhileRunning();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlobalStay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: AppTheme.scrollBehavior,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
