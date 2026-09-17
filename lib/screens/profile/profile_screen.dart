import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../auth/auth_screen.dart';
import 'personal_data_screen.dart';

const _menuFill = Color(0xFFFFFBF2);
const _menuStroke = Color(0xFFFFF3D0);
const _phoneGray = Color(0xFF8C8D8E);
const _badgeRed = Color(0xFFE34043);

const _guestName = 'Владислав Коваленко';
const _guestPhone = '+7 (900) 123-45-67';
const _stubNotificationCount = 2;

/// Вкладка «Профиль» по макету (фрейм 1:14012): аватар, имя и меню.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  AuthRepository get _auth => authRepository ?? AuthRepositoryScope.instance;

  Future<void> _onLogout(BuildContext context) async {
    final confirmed = await showLogoutConfirmDialog(context);
    if (confirmed != true || !context.mounted) return;
    await _auth.signOut();
    if (!context.mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<AuthSession?>(
        valueListenable: AuthRepositoryScope.session,
        builder: (_, session, _) {
          final name = (session?.displayName.isNotEmpty ?? false)
              ? session!.displayName
              : _guestName;
          final phone = (session?.phone.isNotEmpty ?? false)
              ? session!.phone
              : _guestPhone;
          final avatar = session?.avatarUrl;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFEEEFF0),
                  backgroundImage: avatar == null ? null : NetworkImage(avatar),
                  child: avatar == null
                      ? Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.2,
                    color: _phoneGray,
                  ),
                ),
                const SizedBox(height: 36),
                _ProfileMenu(
                  onPersonalData: () => PersonalDataScreen.open(
                    context,
                    authRepository: _auth,
                  ),
                  onLogout: () => _onLogout(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.onPersonalData,
    required this.onLogout,
  });

  final VoidCallback onPersonalData;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItemData>[
      _MenuItemData(
        key: const ValueKey<String>('profile-personal-data'),
        icon: Icons.person_outline,
        label: 'Личные данные',
        onTap: onPersonalData,
      ),
      const _MenuItemData(
        icon: Icons.notifications_none_outlined,
        label: 'Уведомления',
        badgeCount: _stubNotificationCount,
      ),
      const _MenuItemData(
        icon: Icons.help_outline,
        label: 'Написать в поддержку',
      ),
      _MenuItemData(
        key: const ValueKey<String>('profile-logout'),
        icon: Icons.logout,
        label: 'Выйти из аккаунта',
        onTap: onLogout,
      ),
      const _MenuItemData(
        icon: Icons.person_off_outlined,
        label: 'Удалить аккаунт',
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _menuFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _menuStroke),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: _menuStroke,
              ),
            _ProfileMenuRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.onTap,
    this.key,
  });

  final IconData icon;
  final String label;
  final int? badgeCount;
  final VoidCallback? onTap;
  final Key? key;
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.item});

  final _MenuItemData item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: item.key,
        onTap: item.onTap,
        child: SizedBox(
          height: 59,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 24,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (item.badgeCount != null) ...[
                  const SizedBox(width: 8),
                  _NotificationBadge(count: item.badgeCount!),
                ],
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: AppColors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _badgeRed,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1,
          color: AppColors.white,
        ),
      ),
    );
  }
}

Future<bool?> showLogoutConfirmDialog(BuildContext context) {
  return showAppConfirmDialog(
    context,
    title: 'Выйти из аккаунта?',
    dialogKey: 'profile-logout-dialog',
    noKey: 'profile-logout-no',
    yesKey: 'profile-logout-yes',
    barrierLabel: 'logout-confirm',
  );
}
