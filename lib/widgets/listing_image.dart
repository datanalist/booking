import 'package:flutter/material.dart';

/// Фото объявления: сеть (PocketBase) или локальный ассет (тесты / онбординг).
class ListingImage extends StatelessWidget {
  const ListingImage(
    this.src, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String src;
  final BoxFit fit;
  final double? width;
  final double? height;

  bool get _network =>
      src.startsWith('http://') || src.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_network) {
      return Image.network(
        src,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _Placeholder(width: width, height: height),
      );
    }
    if (src.isEmpty) {
      return _Placeholder(width: width, height: height);
    }
    return Image.asset(src, fit: fit, width: width, height: height);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE8E8E8),
      child: SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.home_outlined, color: Color(0xFF9A9A9A)),
        ),
      ),
    );
  }
}
