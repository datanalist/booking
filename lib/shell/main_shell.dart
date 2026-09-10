import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      label: 'Поиск жилья',
      // TODO(figma): Iconly/Light-Outline/Search и Bold/Search
      // https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking?node-id=1-16160
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
    ),
    _TabDestination(
      label: 'Бронирования',
      // TODO(figma): Iconly Calendar
      // https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking?node-id=1-11948
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
    ),
    _TabDestination(
      label: 'Избранное',
      // TODO(figma): Iconly/Light/Heart и Bold/Heart
      // https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking?node-id=1-12120
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
    ),
    _TabDestination(
      label: 'Чат',
      // TODO(figma): Iconly/Light-Outline/Chat
      // https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking?node-id=1-13967
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    _TabDestination(
      label: 'Профиль',
      // TODO(figma): Iconly Profile / User
      // https://www.figma.com/design/zqPAmK0qrRQtqMp5IP3K5u/Booking?node-id=1-14012
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

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
        bottomNavigationBar: _AppTabBar(
          currentIndex: _index,
          destinations: _tabs,
          onTap: (value) => setState(() => _index = value),
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
  final IconData icon;
  final IconData selectedIcon;
}

/// Нижняя панель 393×68 + Home Indicator по макету «Tab bar + Indicator».
class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabDestination> destinations;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.tabBarBorder),
          ),
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
    required this.onTap,
  });

  final _TabDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.tabInactive;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 24,
            color: color,
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
