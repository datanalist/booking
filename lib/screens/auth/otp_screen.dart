import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.challenge,
    this.authRepository,
    this.onVerified,
    this.resendSeconds = 20,
  });

  final OtpChallenge challenge;
  final AuthRepository? authRepository;
  final ValueChanged<AuthSession>? onVerified;
  final int resendSeconds;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late int _left = widget.resendSeconds;
  Timer? _timer;
  var _busy = false;
  String? _error;
  late OtpChallenge _challenge = widget.challenge;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;

  bool get _canResend => _left <= 0 && !_busy;
  bool get _canContinue => _code.text.trim().length == 5 && !_busy;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_left <= 1) {
        timer.cancel();
        setState(() => _left = 0);
        return;
      }
      setState(() => _left -= 1);
    });
  }

  String get _subtitle {
    if (_challenge.channel == OtpChannel.email) {
      return 'Мы отправили письмо с кодом активации на ${_challenge.destination}';
    }
    return 'Мы отправили SMS-сообщение с кодом активации на номер ${_challenge.destination}';
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_challenge.channel == OtpChannel.email) {
        _challenge = await _auth.requestEmailOtp(_challenge.destination);
      } else {
        _challenge = await _auth.requestPhoneOtp(_challenge.destination);
      }
      _code.clear();
      _startTimer();
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_canContinue) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = _challenge.channel == OtpChannel.email
          ? await _auth.verifyEmailOtp(
              otpId: _challenge.otpId,
              code: _code.text.trim(),
            )
          : await _auth.verifyPhoneOtp(
              otpId: _challenge.otpId,
              code: _code.text.trim(),
            );
      if (!mounted) return;
      widget.onVerified?.call(session);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerLabel =
        '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Введите код',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    height: 45 / 32,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 22 / 16,
                    color: Color(0xFF1A1B1C),
                  ),
                ),
                const SizedBox(height: 50),
                Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 5; i++)
                          _OtpBox(
                            value: i < _code.text.length ? _code.text[i] : '',
                            focused: _focus.hasFocus && i == _code.text.length,
                          ),
                      ],
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          key: const ValueKey<String>('auth-otp-field'),
                          controller: _code,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorSnack(message: _error!),
                ],
                const Spacer(),
                InkWell(
                  onTap: _canResend ? _resend : null,
                  child: SizedBox(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Отправить код повторно',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: _canResend
                                ? AppColors.orange
                                : const Color(0xFF89919D),
                          ),
                        ),
                        if (!_canResend) ...[
                          const SizedBox(width: 16),
                          Container(
                            width: 56,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x14767680),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              timerLabel,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                color: Color(0xFF1A1B1C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _canContinue ? _submit : null,
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.value, required this.focused});

  final String value;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused ? AppColors.orange : const Color(0xFFE2E5EA),
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 24,
          color: Color(0xFF1A1B1C),
        ),
      ),
    );
  }
}

class _ErrorSnack extends StatelessWidget {
  const _ErrorSnack({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('auth-otp-error'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          color: Color(0xFFE34043),
        ),
      ),
    );
  }
}
