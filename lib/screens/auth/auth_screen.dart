import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_repository.dart';
import '../../shell/main_shell.dart';
import '../../theme/app_theme.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

/// Копирайт галочки с экрана Email `1:14841` / чекбокс `1:14848`.
const kAuthTermsPrefix = 'Я прочитал(а) и согласен(сна) с ';
const kAuthTermsLinkLabel = 'Условиями использования';
const kAuthPrivacyLinkLabel = 'Политикой конфиденциальности';

const _authBg = Color(0xFFF7F7F6);
const _fieldHint = Color(0xFFC7C7CC);
const _termsGray = Color(0xFF8E8E93);
const _disabledFill = Color(0x1A1D1B20);
const _disabledLabel = Color(0x991D1B20);

/// Экран авторизации по макетам `1:14841`, `1:14880`, `1:14900`.
/// Одно поле: email или телефон. Email — реальный OTP, телефон — заглушка.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.authRepository,
    this.onSignedIn,
  });

  final AuthRepository? authRepository;

  /// После полного входа. Если не задан — открывается оболочка.
  final ValueChanged<AuthSession>? onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _identity = TextEditingController();
  final _identityFocus = FocusNode();
  bool _busy = false;
  bool _acceptedTerms = false;
  String? _error;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;

  @override
  void dispose() {
    _identity.dispose();
    _identityFocus.dispose();
    super.dispose();
  }

  String get _identityText => _identity.text.trim();

  bool get _canContinue =>
      _acceptedTerms && _identityText.isNotEmpty && !_busy;

  bool get _isEmail => _looksLikeEmail(_identityText);

  bool get _isPhone => _looksLikePhone(_identityText);

  static bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  static bool _looksLikePhone(String value) {
    if (value.contains('@')) return false;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final OtpChallenge challenge;
      if (_isEmail) {
        challenge = await _auth.requestEmailOtp(_identityText);
      } else if (_isPhone) {
        challenge = await _auth.requestPhoneOtp(_identityText);
      } else {
        throw const AuthException(
          'Введите корректный email или номер телефона',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => OtpScreen(
            challenge: challenge,
            authRepository: _auth,
            onVerified: _afterVerified,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось продолжить. Проверьте соединение');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _afterVerified(AuthSession session) {
    if (session.profileComplete) {
      _finish(session);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => RegisterScreen(
          initialEmail: session.email.isNotEmpty
              ? session.email
              : (_isEmail ? _identityText : ''),
          initialPhone: session.phone.isNotEmpty
              ? session.phone
              : (_isPhone ? _identityText : ''),
          authRepository: _auth,
          onCompleted: _finish,
        ),
      ),
    );
  }

  void _finish(AuthSession session) {
    if (widget.onSignedIn != null) {
      widget.onSignedIn!(session);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const MainShell();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _authBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _authBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Авторизация',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 45 / 28,
                    color: Color(0xFF000000),
                  ),
                ),
                const SizedBox(height: 102),
                _AuthIdentityField(
                  controller: _identity,
                  focusNode: _identityFocus,
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const ValueKey<String>('auth-email-error'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.3,
                      color: Color(0xFFE34043),
                    ),
                  ),
                ],
                const Spacer(),
                _AuthTermsCheckbox(
                  accepted: _acceptedTerms,
                  onChanged: (value) => setState(() => _acceptedTerms = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _canContinue ? _onContinue : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: _disabledFill,
                    disabledForegroundColor: _disabledLabel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Далее'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIdentityField extends StatelessWidget {
  const _AuthIdentityField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        key: const ValueKey<String>('auth-identity-field'),
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.45,
          color: Color(0xFF000000),
        ),
        decoration: InputDecoration(
          hintText: 'Введите Email или номер телефона',
          hintStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 1.45,
            color: _fieldHint,
          ),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Figma `1:14848`: ряд 343×48, бокс 48×48, текст 295×32 со смещением y=8.
class _AuthTermsCheckbox extends StatefulWidget {
  const _AuthTermsCheckbox({
    required this.accepted,
    required this.onChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  State<_AuthTermsCheckbox> createState() => _AuthTermsCheckboxState();
}

class _AuthTermsCheckboxState extends State<_AuthTermsCheckbox> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  static const _copyStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: -0.4,
    color: _termsGray,
  );

  static const _linkStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: -0.4,
    color: AppColors.orange,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.orange,
  );

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(
            title: 'Условия использования',
            keyName: 'auth-terms-page',
          );
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(
            title: 'Политика конфиденциальности',
            keyName: 'auth-privacy-page',
          );
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _toggle() => widget.onChanged(!widget.accepted);

  void _openLegal({required String title, required String keyName}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AuthLegalPage(title: title, keyName: keyName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('auth-terms-slot'),
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FigmaCheckboxMark(accepted: widget.accepted, onTap: _toggle),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 32,
                child: Text.rich(
                  TextSpan(
                    style: _copyStyle,
                    children: [
                      const TextSpan(text: kAuthTermsPrefix),
                      TextSpan(
                        text: kAuthTermsLinkLabel,
                        style: _linkStyle,
                        recognizer: _termsTap,
                      ),
                      const TextSpan(text: ' и '),
                      TextSpan(
                        text: kAuthPrivacyLinkLabel,
                        style: _linkStyle,
                        recognizer: _privacyTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FigmaCheckboxMark extends StatelessWidget {
  const _FigmaCheckboxMark({required this.accepted, required this.onTap});

  final bool accepted;
  final VoidCallback onTap;

  static const _box = 18.0;
  static const _radius = 2.0;
  static const _uncheckedStroke = Color(0x4D000000);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: accepted,
      label: 'Согласие с условиями',
      child: GestureDetector(
        key: const ValueKey<String>('auth-terms-checkbox'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: _box,
              height: _box,
              decoration: BoxDecoration(
                color: accepted ? AppColors.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(_radius),
                border: accepted
                    ? null
                    : Border.all(color: _uncheckedStroke, width: 2),
              ),
              alignment: Alignment.center,
              child: accepted
                  ? const Icon(Icons.check, size: 12, color: AppColors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLegalPage extends StatelessWidget {
  const _AuthLegalPage({required this.title, required this.keyName});

  final String title;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          title,
          key: ValueKey<String>(keyName),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(
          'Текст документа появится здесь.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 1.45,
            color: Color(0xFF1A1B1C),
          ),
        ),
      ),
    );
  }
}
