import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_repository.dart';
import '../../data/birthdate.dart';
import '../../theme/app_theme.dart';
import 'photo_access.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialEmail = '',
    this.initialPhone = '',
    this.authRepository,
    this.photoLibrary,
    this.onCompleted,
  });

  final String initialEmail;
  final String initialPhone;
  final AuthRepository? authRepository;
  final PhotoLibrary? photoLibrary;
  final ValueChanged<AuthSession>? onCompleted;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final _first = TextEditingController();
  late final _last = TextEditingController();
  late final _birth = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  File? _avatar;
  var _busy = false;
  String? _error;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;
  PhotoLibrary get _photos => widget.photoLibrary ?? DevicePhotoLibrary();

  bool get _canContinue =>
      _first.text.trim().isNotEmpty &&
      _last.text.trim().isNotEmpty &&
      _birth.text.trim().length == 10 &&
      _email.text.trim().isNotEmpty &&
      !_busy;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _birth.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _onAvatarTap() async {
    final choice = await showPhotoAccessDialog(context);
    if (!mounted || choice == null || choice == PhotoAccessChoice.deny) return;
    final granted = await _photos.requestGallery(
      limited: choice == PhotoAccessChoice.limited,
    );
    if (!granted || !mounted) return;
    final picked = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (context) => PhotoPickerScreen(library: _photos),
      ),
    );
    if (picked == null || !mounted) return;
    final cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (context) => PhotoCropScreen(file: picked)),
    );
    if (cropped == null || !mounted) return;
    setState(() => _avatar = cropped);
  }

  Future<void> _submit() async {
    if (!_canContinue) return;
    DateTime birthdate;
    try {
      birthdate = parseBirthdate(_birth.text);
    } on BirthdateParseException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    var limited = false;
    if (!isAdult(birthdate)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            key: const ValueKey<String>('auth-age-alert'),
            title: const Text('Возрастное ограничение'),
            content: const Text(
              'Вам нет 18 лет. Доступен только просмотр объявлений, '
              'бронирование и остальной функционал ограничены.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Понятно'),
              ),
            ],
          );
        },
      );
      if (proceed != true || !mounted) return;
      limited = true;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _auth.completeProfile(
        firstName: _first.text,
        lastName: _last.text,
        birthdate: birthdate,
        email: _email.text,
        phone: widget.initialPhone,
        avatar: _avatar,
        limitedBrowse: limited,
      );
      if (!mounted) return;
      widget.onCompleted?.call(session);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Регистрация',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    height: 45 / 32,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Заполните информацию о себе',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 22 / 16,
                    color: Color(0xFF1A1B1C),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    key: const ValueKey<String>('auth-register-avatar'),
                    onTap: _onAvatarTap,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFFEEEFF0),
                            backgroundImage:
                                _avatar == null ? null : FileImage(_avatar!),
                            child: _avatar == null
                                ? const Icon(
                                    Icons.person_outline,
                                    size: 40,
                                    color: Color(0xFF89919D),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _RegisterField(
                  keyName: 'auth-register-first',
                  controller: _first,
                  hint: 'Имя',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _RegisterField(
                  keyName: 'auth-register-last',
                  controller: _last,
                  hint: 'Фамилия',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _RegisterField(
                  keyName: 'auth-register-birth',
                  controller: _birth,
                  hint: 'ДД.ММ.ГГГГ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_BirthdateFormatter()],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _RegisterField(
                  keyName: 'auth-register-email',
                  controller: _email,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const ValueKey<String>('auth-register-error'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      color: Color(0xFFE34043),
                    ),
                  ),
                ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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

class _BirthdateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final masked = maskBirthdateInput(newValue.text);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.keyName,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  final String keyName;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: Color(0xFF1A1B1C),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Color(0xFF89919D),
          ),
          filled: true,
          fillColor: const Color(0xFFF4F4F4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
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
