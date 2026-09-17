import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/auth_repository.dart';
import '../shell/main_shell.dart';
import '../theme/app_theme.dart';
import 'auth/register_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.delay = const Duration(milliseconds: 1800),
  });

  final Duration delay;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
  }

  Future<void> _goNext() async {
    for (final page in onboardingPages) {
      precacheImage(AssetImage(page.imageAsset), context);
    }
    final restored = AuthRepositoryScope.instance.restoreSession();
    await Future.wait<void>([
      Future<void>.delayed(widget.delay),
      restored.then((_) {}),
    ]);
    if (!mounted) return;
    final session = AuthRepositoryScope.session.value ??
        AuthRepositoryScope.instance.currentSession();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return _homeFor(session);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _homeFor(AuthSession? session) {
    if (session == null || session.userId.isEmpty) {
      return const OnboardingScreen();
    }
    if (session.profileComplete) {
      return const MainShell();
    }
    return RegisterScreen(
      initialEmail: session.email,
      initialPhone: session.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: SvgPicture.asset(
            'images/logo.svg',
            width: 198,
            height: 160,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
