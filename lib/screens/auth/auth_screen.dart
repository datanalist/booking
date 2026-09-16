import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_repository.dart';
import '../../shell/main_shell.dart';
import '../../theme/app_theme.dart';

/// Заглушка email: подставляется по тапу на пустое поле, дальше можно править.
/// Соответствует записи `users.email` из `scripts/seed_auth_stub.py`.
const kAuthEmailStub = 'example@mail.com';

/// Копирайт галочки с экрана Email `1:14841` / чекбокс `1:14848`.
const kAuthTermsPrefix = 'Я прочитал(а) и согласен(сна) с ';
const kAuthTermsLinkLabel = 'Условиями использования';
const kAuthPrivacyLinkLabel = 'Политикой конфиденциальности';

/// Вкладки входа по макету: Email `1:14841`, телефон `1:14851` (агент 3).
enum AuthEntryMethod { email, phone }

/// Экран авторизации. Телефон и OTP — заглушки под агента 3.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMethod = AuthEntryMethod.email,
    this.authRepository,
    this.onSignedIn,
    this.onPhoneContinue,
  });

  final AuthEntryMethod initialMethod;
  final AuthRepository? authRepository;

  /// После успешного входа в PocketBase. Если не задан — открывается оболочка.
  final ValueChanged<AuthSession>? onSignedIn;

  /// Агент 3: сценарий телефона + OTP. Сюда не ходим с вкладки Email.
  final ValueChanged<String>? onPhoneContinue;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthEntryMethod _method = widget.initialMethod;
  final _email = TextEditingController();
  final _emailFocus = FocusNode();
  bool _busy = false;
  bool _acceptedTerms = false;
  String? _error;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;

  static const _fieldFill = Color(0xFFF4F4F4);
  static const _fieldBorder = Color(0xFFE2E5EA);
  static const _hint = Color(0xFF89919D);

  @override
  void dispose() {
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool get _canContinueEmail =>
      _acceptedTerms && _email.text.trim().isNotEmpty && !_busy;

  bool get _canContinue => _method == AuthEntryMethod.email
      ? _canContinueEmail
      : _acceptedTerms && !_busy;

  void _fillEmailStubIfEmpty() {
    if (_email.text.isNotEmpty) return;
    _email.value = const TextEditingValue(
      text: kAuthEmailStub,
      selection: TextSelection.collapsed(offset: kAuthEmailStub.length),
    );
    setState(() {});
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    if (_method == AuthEntryMethod.phone) {
      widget.onPhoneContinue?.call('');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _auth.signInWithEmail(_email.text.trim());
      if (!mounted) return;
      if (widget.onSignedIn != null) {
        widget.onSignedIn!(session);
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return const MainShell();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось войти. Проверьте соединение');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Авторизация',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    height: 45 / 32,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                _AuthMethodTabs(
                  value: _method,
                  onChanged: (value) => setState(() => _method = value),
                ),
                const SizedBox(height: 42),
                if (_method == AuthEntryMethod.email)
                  _EmailField(
                    controller: _email,
                    focusNode: _emailFocus,
                    fill: _fieldFill,
                    border: _fieldBorder,
                    hintColor: _hint,
                    onTap: _fillEmailStubIfEmpty,
                    onChanged: (_) => setState(() {}),
                  )
                else
                  const _PhoneAuthPlaceholder(),
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
                    disabledBackgroundColor: const Color(0x66F88A2A),
                    disabledForegroundColor: AppColors.white,
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
                      : const Text('Продолжить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthMethodTabs extends StatelessWidget {
  const _AuthMethodTabs({required this.value, required this.onChanged});

  final AuthEntryMethod value;
  final ValueChanged<AuthEntryMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: CupertinoSlidingSegmentedControl<AuthEntryMethod>(
        groupValue: value,
        backgroundColor: const Color(0x1F767680),
        thumbColor: AppColors.white,
        padding: const EdgeInsets.all(2),
        children: {
          AuthEntryMethod.email: _label(
            'Email',
            selected: value == AuthEntryMethod.email,
          ),
          AuthEntryMethod.phone: _label(
            'Телефон',
            selected: value == AuthEntryMethod.phone,
          ),
        },
        onValueChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  static Widget _label(String text, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 13,
          height: 20 / 13,
          color: selected ? AppColors.textPrimary : const Color(0xFF3C3C43),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.fill,
    required this.border,
    required this.hintColor,
    required this.onTap,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color fill;
  final Color border;
  final Color hintColor;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        key: const ValueKey<String>('auth-email-field'),
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        onTap: onTap,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          height: 1.45,
          color: Color(0xFF1A1B1C),
        ),
        decoration: InputDecoration(
          hintText: 'Email',
          hintStyle: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 1.45,
            color: hintColor,
          ),
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.orange),
          ),
        ),
      ),
    );
  }
}

/// Каркас вкладки телефона без OTP / заглушки номера — это задача агента 3.
class _PhoneAuthPlaceholder extends StatelessWidget {
  const _PhoneAuthPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: ValueKey<String>('auth-phone-placeholder'),
      height: 56,
      child: ColoredBox(color: Colors.transparent),
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
    color: Color(0xFF1A1B1C),
  );

  static const _linkStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
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

  static const _box = 22.0;
  static const _radius = 6.0;
  static const _uncheckedStroke = Color(0xFFC7C7CC);

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
                border: Border.all(
                  color: accepted ? AppColors.orange : _uncheckedStroke,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: accepted
                  ? const Icon(Icons.check, size: 16, color: AppColors.white)
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
