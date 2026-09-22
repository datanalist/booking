import 'package:flutter/material.dart';

import '../screens/listing/listing_icons.dart';
import '../screens/search/search_listing.dart';
import '../theme/app_theme.dart';
import 'listing_image.dart';

const _meta = Color(0xFF525353);
const _badgeGreen = Color.fromRGBO(73, 204, 95, 0.97);
const _chatBorder = Color.fromRGBO(251, 192, 40, 0.17);
const _ink = Color(0xFF1A1B1D);

/// Блок «Владелец» (Figma `1:13522`): фото, имя, рейтинг, чат, бейджи.
class ListingHostSection extends StatelessWidget {
  const ListingHostSection({
    super.key,
    required this.host,
    this.fallbackName = '',
    this.fallbackAvatar = '',
    this.onChat,
    this.avatarSize = 64,
  });

  final ListingHost host;
  final String fallbackName;
  final String fallbackAvatar;
  final VoidCallback? onChat;
  final double avatarSize;

  String get _name {
    final fromHost = host.name.trim();
    if (fromHost.isNotEmpty && fromHost != 'Хозяин') return fromHost;
    final fallback = fallbackName.trim();
    return fallback.isEmpty ? 'Хозяин' : fallback;
  }

  String get _avatar {
    return host.avatarUrl.isNotEmpty ? host.avatarUrl : fallbackAvatar;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Владелец',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.4,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Avatar(label: _name, url: _avatar, size: avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.4,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        host.rating,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.5,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          reviewCountLabel(host.reviewCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.5,
                            color: _meta,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _HostStars(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onChat != null) ...[
              const SizedBox(width: 8),
              _HostChatButton(onTap: onChat!),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (host.verified)
              const _HostBadge(
                icon: ListingFigmaIcon.security,
                label: 'Верификация пройдена',
              ),
            if (host.years > 0)
              _HostBadge(
                icon: ListingFigmaIcon.time,
                label: yearsHostingLabel(host.years),
              ),
          ],
        ),
      ],
    );
  }
}

class _HostChatButton extends StatelessWidget {
  const _HostChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(side: BorderSide(color: _chatBorder)),
      child: InkWell(
        key: const ValueKey('listing-host-chat'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Image(
              image: AssetImage(
                'images/SearchBarIcons/Light-Outline/Chat.png',
              ),
              width: 17.91,
              height: 17.912,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _HostBadge extends StatelessWidget {
  const _HostBadge({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: _badgeGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.5,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostStars extends StatelessWidget {
  const _HostStars();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListingFigmaIcon.star12,
        SizedBox(width: 2),
        ListingFigmaIcon.star12,
        SizedBox(width: 2),
        ListingFigmaIcon.star12,
        SizedBox(width: 2),
        ListingFigmaIcon.star12,
        SizedBox(width: 2),
        ListingFigmaIcon.star12,
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.size, this.url = ''});

  final String label;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: ListingImage(url, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFE3B7),
      child: Text(
        label.isEmpty ? '?' : label.characters.first,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: _ink,
        ),
      ),
    );
  }
}
