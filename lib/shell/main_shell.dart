import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chats_repository.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import '../theme/app_theme.dart';

/// Гостевой/основной каркас клиента с нижней панелью.
/// Вкладки наполняют агенты в `lib/screens/*`; этот файл лучше не трогать.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  static const _tabs = <_TabDestination>[
    _TabDestination(
      label: 'Поиск',
      icon: 'images/SearchBarIcons/Light-Outline/Search.png',
      selectedIcon: 'images/SearchBarIcons/Bold/Search.png',
    ),
    _TabDestination(
      label: 'Брони',
      icon: 'images/SearchBarIcons/Light-Outline/Home.png',
      selectedIcon: 'images/SearchBarIcons/Bold/Home.png',
    ),
    _TabDestination(
      label: 'Избранное',
      icon: 'images/SearchBarIcons/Light-Outline/Heart.png',
      selectedIcon: 'images/SearchBarIcons/Bold/Heart.png',
    ),
    _TabDestination(
      label: 'Чаты',
      icon: 'images/SearchBarIcons/Light-Outline/Chat.png',
      selectedIcon: 'images/SearchBarIcons/Bold/Chat.png',
    ),
    _TabDestination(
      label: 'Профиль',
      icon: 'images/SearchBarIcons/Light-Outline/Group.png',
      selectedIcon: 'images/SearchBarIcons/Bold/Profile.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (_index == 0 || _index == 1
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: AppColors.tabBarFill,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: IndexedStack(
          index: _index,
          children: const [
            SearchScreen(),
            BookingsScreen(),
            FavoritesScreen(),
            ChatScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: ChatsRepositoryScope.unreadCount,
          builder: (context, unread, _) {
            return _AppTabBar(
              currentIndex: _index,
              destinations: _tabs,
              unreadChats: unread,
              onTap: (value) => setState(() => _index = value),
            );
          },
        ),
      ),
    );
  }
}

class _TabDestination {
  const _TabDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String icon;
  final String selectedIcon;
}

/// Нижняя панель 393×68 + Home Indicator по макету «Tab bar + Indicator».
class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.currentIndex,
    required this.destinations,
    required this.unreadChats,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabDestination> destinations;
  final int unreadChats;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.tabBarFill,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.tabBarBorder)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _TabItem(
                      destination: destinations[i],
                      selected: i == currentIndex,
                      badgeCount: destinations[i].label == 'Чаты'
                          ? unreadChats
                          : 0,
                      onTap: () => onTap(i),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.destination,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final _TabDestination destination;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.tabInactive;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  selected ? destination.selectedIcon : destination.icon,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  color: color,
                  excludeFromSemantics: true,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -8,
                    right: -10,
                    child: _IncomingBadge(count: badgeCount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 10,
              height: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Красный счётчик входящих на иконке «Чаты»: тот же кружок 24×24, что в макете.
class _IncomingBadge extends StatelessWidget {
  const _IncomingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      key: const ValueKey('chats-tab-unread-badge'),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: AppColors.badgeRed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
