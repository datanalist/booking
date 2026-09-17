import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';

/// Waiting screen after a magic-link email is sent. No code entry.
class MagicLinkWaitScreen extends StatefulWidget {
  const MagicLinkWaitScreen({
    super.key,
    required this.challenge,
    this.authRepository,
    this.onVerified,
    this.resendSeconds = 20,
    this.pollInterval = const Duration(seconds: 2),
  });

  final OtpChallenge challenge;
  final AuthRepository? authRepository;
  final ValueChanged<AuthSession>? onVerified;
  final int resendSeconds;
  final Duration pollInterval;

  @override
  State<MagicLinkWaitScreen> createState() => _MagicLinkWaitScreenState();
}

class _MagicLinkWaitScreenState extends State<MagicLinkWaitScreen> {
  late int _left = widget.resendSeconds;
  Timer? _timer;
  Timer? _poll;
  var _busy = false;
  var _completed = false;
  var _polling = false;
  String? _error;
  late OtpChallenge _challenge = widget.challenge;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;

  bool get _canResend => _left <= 0 && !_busy;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startPoll();
    AuthRepositoryScope.session.addListener(_onSession);
    AuthRepositoryScope.authLinkError.addListener(_onLinkError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onSession();
      _onLinkError();
      unawaited(_pollOnce());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    AuthRepositoryScope.session.removeListener(_onSession);
    AuthRepositoryScope.authLinkError.removeListener(_onLinkError);
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

  void _startPoll() {
    _poll?.cancel();
    if (widget.pollInterval <= Duration.zero) return;
    _poll = Timer.periodic(widget.pollInterval, (_) {
      unawaited(_pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    if (_completed || _polling || !mounted) return;
    _polling = true;
    try {
      final session = await _auth.pollMagicLogin(_challenge.otpId);
      if (session != null) {
        AuthRepositoryScope.session.value = session;
        _onSession();
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      _polling = false;
    }
  }

  void _onSession() {
    final session = AuthRepositoryScope.session.value;
    if (session == null || session.userId.isEmpty || _completed) return;
    _completed = true;
    _poll?.cancel();
    widget.onVerified?.call(session);
  }

  void _onLinkError() {
    final message = AuthRepositoryScope.authLinkError.value;
    if (message == null || message.isEmpty || !mounted) return;
    setState(() => _error = message);
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    AuthRepositoryScope.authLinkError.value = null;
    try {
      _challenge = await _auth.requestEmailOtp(_challenge.destination);
      _startTimer();
    } on AuthException catch (error) {
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
                  'Проверьте почту',
                  key: ValueKey<String>('auth-magic-wait'),
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
                  'Мы отправили письмо на ${_challenge.destination}. '
                  'Откройте его на этом компьютере и нажмите «Авторизоваться», '
                  'затем вернитесь сюда — вход подхватится сам, без магазина приложений.',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 22 / 16,
                    color: Color(0xFF1A1B1C),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const ValueKey<String>('auth-magic-error'),
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        color: Color(0xFFE34043),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_busy)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _canResend ? _resend : null,
                  child: SizedBox(
                    height: 38,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Отправить письмо повторно',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
