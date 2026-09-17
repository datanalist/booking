import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/auth_repository.dart';
import '../../data/birthdate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../auth/auth_screen.dart';
import '../auth/photo_access.dart';

const _emailChangeTitle = 'Изменить email?';
const _emailChangeBody =
    'После смены email будет выполнен выход из аккаунта. Войдите снова по новому адресу.';

const _titleColor = Color(0xFF1A1B1D);
const _labelColor = Color(0xFF525353);
const _backBorder = Color(0xFFFFE4B8);
const _avatarFill = Color(0xFFEEEFF0);

/// Экран «Личные данные» по макету Figma `1:14538`.
class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({
    super.key,
    this.authRepository,
    this.photoLibrary,
  });

  final AuthRepository? authRepository;
  final PhotoLibrary? photoLibrary;

  static Future<void> open(
    BuildContext context, {
    AuthRepository? authRepository,
    PhotoLibrary? photoLibrary,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PersonalDataScreen(
          authRepository: authRepository,
          photoLibrary: photoLibrary,
        ),
      ),
    );
  }

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _birth;
  late final TextEditingController _email;
  File? _avatar;
  var _busy = false;
  String? _error;

  AuthRepository get _auth =>
      widget.authRepository ?? AuthRepositoryScope.instance;
  PhotoLibrary get _photos => widget.photoLibrary ?? DevicePhotoLibrary();

  AuthSession? get _session =>
      _auth.currentSession() ?? AuthRepositoryScope.session.value;

  bool get _canSave =>
      _first.text.trim().isNotEmpty &&
      _last.text.trim().isNotEmpty &&
      _birth.text.trim().length == 10 &&
      _email.text.trim().isNotEmpty &&
      !_busy;

  bool get _emailChanged {
    final current = (_session?.email ?? '').trim().toLowerCase();
    final next = _email.text.trim().toLowerCase();
    return current != next;
  }

  void _restoreSessionEmail() {
    final current =
        (_auth.currentSession() ?? AuthRepositoryScope.session.value)?.email ??
        '';
    setState(() => _email.text = current);
  }

  @override
  void initState() {
    super.initState();
    final session = _session;
    _first = TextEditingController(text: session?.firstName ?? '');
    _last = TextEditingController(text: session?.lastName ?? '');
    _birth = TextEditingController(
      text: session?.birthdate == null
          ? ''
          : formatBirthdate(session!.birthdate!),
    );
    _email = TextEditingController(text: session?.email ?? '');
  }

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

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    DateTime initial;
    try {
      initial = parseBirthdate(_birth.text, now: now);
    } catch (_) {
      initial = DateTime(now.year - 25, now.month, now.day);
    }
    if (initial.isAfter(lastDate)) initial = lastDate;
    final firstDate = DateTime(1920, 1, 1);
    if (initial.isBefore(firstDate)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru', 'RU'),
    );
    if (picked == null || !mounted) return;
    setState(() => _birth.text = formatBirthdate(picked));
  }

  Future<void> _submit() async {
    if (!_canSave) return;
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
            key: const ValueKey<String>('personal-data-age-alert'),
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
    final emailChanged = _emailChanged;
    if (emailChanged) {
      final confirmed = await showEmailChangeConfirmDialog(context);
      if (!mounted) return;
      if (confirmed != true) {
        _restoreSessionEmail();
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.updatePersonalData(
        firstName: _first.text,
        lastName: _last.text,
        birthdate: birthdate,
        email: _email.text,
        avatar: _avatar,
        limitedBrowse: limited,
      );
      if (!mounted) return;
      if (emailChanged) {
        await _auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) {
              return AuthScreen(authRepository: _auth);
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (route) => false,
        );
        return;
      }
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final networkAvatar = session?.avatarUrl;
    ImageProvider? avatarImage;
    if (_avatar != null) {
      avatarImage = FileImage(_avatar!);
    } else if (networkAvatar != null && networkAvatar.isNotEmpty) {
      avatarImage = NetworkImage(networkAvatar);
    }
    final initialsSource = '${_first.text} ${_last.text}'.trim();
    final initial = initialsSource.isEmpty
        ? '?'
        : initialsSource[0].toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const ValueKey<String>('personal-data-screen'),
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _BackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Личные данные',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1,
                            letterSpacing: 0.018,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            key: const ValueKey<String>('personal-data-avatar'),
                            onTap: _onAvatarTap,
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: _avatarFill,
                                    backgroundImage: avatarImage,
                                    child: avatarImage == null
                                        ? Text(
                                            initial,
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 24,
                                              color: AppColors.textPrimary,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const Positioned(
                                    right: -40,
                                    bottom: -50,
                                    child: IgnorePointer(
                                      child: _PhotoBadge(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _LabeledField(
                          label: 'Имя',
                          keyName: 'personal-data-first',
                          controller: _first,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Фамилия',
                          keyName: 'personal-data-last',
                          controller: _last,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Дата рождения',
                          keyName: 'personal-data-birth',
                          controller: _birth,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [_BirthdateFormatter()],
                          onChanged: (_) => setState(() {}),
                          trailing: _CalendarButton(onTap: _pickBirthdate),
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'E-mail',
                          keyName: 'personal-data-email',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            key: const ValueKey<String>('personal-data-error'),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey<String>('personal-data-save'),
                    onPressed: _canSave ? _submit : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.orange,
                      disabledBackgroundColor: const Color(0x66F88A2A),
                      disabledForegroundColor: AppColors.white,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
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
                        : const Text('Сохранить'),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Назад',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(
          side: BorderSide(color: _backBorder),
        ),
        child: InkWell(
          key: const ValueKey<String>('personal-data-back'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(child: _BackArrowIcon()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrowIcon extends StatelessWidget {
  const _BackArrowIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 2,
      child: SvgPicture.asset(
        'images/profile/arrow-left.svg',
        width: 13.1667,
        height: 7.33333,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'images/profile/photo-edit.svg',
      width: 104,
      height: 104,
      excludeFromSemantics: true,
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('personal-data-calendar'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: _CalendarIcon(),
        ),
      ),
    );
  }
}

class _CalendarIcon extends StatelessWidget {
  const _CalendarIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'images/profile/calendar.svg',
      width: 16.5,
      height: 18.1667,
      excludeFromSemantics: true,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.keyName,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.trailing,
  });

  final String label;
  final String keyName;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.5,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.orange),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
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
                      height: 1.45,
                      color: _titleColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool?> showEmailChangeConfirmDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    title: _emailChangeTitle,
    body: _emailChangeBody,
    dialogKey: 'personal-data-email-dialog',
    noKey: 'personal-data-email-no',
    yesKey: 'personal-data-email-yes',
    barrierLabel: 'email-change-confirm',
  );
}

class _BirthdateFormatter extends TextInputFormatter {
  const _BirthdateFormatter();

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
