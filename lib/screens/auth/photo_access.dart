import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/auth_callback.dart';
import '../../theme/app_theme.dart';

class PhotoAssetItem {
  const PhotoAssetItem({required this.id});

  final String id;
}

abstract class PhotoLibrary {
  Future<bool> requestGallery({required bool limited});
  Future<bool> requestCamera();
  Future<List<PhotoAssetItem>> list({int limit = 90});
  Future<Uint8List?> thumbnail(PhotoAssetItem item);
  Future<File?> load(PhotoAssetItem item);
  Future<File?> capture();
  Future<File?> pickFromGallery();
}

Future<bool> requestGalleryAndCamera(
  PhotoLibrary library, {
  required bool limited,
}) async {
  final gallery = await library.requestGallery(limited: limited);
  if (!gallery) return false;
  return library.requestCamera();
}

/// True only when the OS actually allows access. Denied / restricted
/// / permanently denied must not be treated as a grant.
bool photoPermissionAllowsAccess(PermissionStatus status) {
  return status.isGranted || status.isLimited;
}

class DevicePhotoLibrary implements PhotoLibrary {
  DevicePhotoLibrary({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<bool> requestGallery({required bool limited}) async {
    var status = await Permission.photos.request();
    if (photoPermissionAllowsAccess(status)) return true;
    if (!Platform.isAndroid) return false;
    status = await Permission.storage.request();
    return photoPermissionAllowsAccess(status);
  }

  @override
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return photoPermissionAllowsAccess(status);
  }

  @override
  Future<List<PhotoAssetItem>> list({int limit = 90}) async => const [];

  @override
  Future<Uint8List?> thumbnail(PhotoAssetItem item) async => null;

  @override
  Future<File?> load(PhotoAssetItem item) => pickFromGallery();

  @override
  Future<File?> capture() => _pick(ImageSource.camera);

  @override
  Future<File?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<File?> _pick(ImageSource source) async {
    final shot = await _picker.pickImage(source: source, imageQuality: 92);
    if (shot == null) return null;
    return File(shot.path);
  }
}

/// Remembers an in-app photo/camera grant next to [AuthCallback.prefsAuthKey].
///
/// A grant is stored only after the user confirms the access sheet and the OS
/// allows gallery and camera. Deny (sheet or OS) is never persisted, so the
/// next avatar tap asks again.
class PhotoAccessMemory {
  PhotoAccessMemory({this._store});

  /// In-memory store for widget tests (avoids the SharedPreferences plugin).
  factory PhotoAccessMemory.memory({bool granted = false}) {
    return PhotoAccessMemory(
      store: <String, bool>{
        if (granted) prefsKey: true,
      },
    );
  }

  /// Prefs key beside `pb_auth`.
  static const prefsKey = 'photo_access_granted';

  static PhotoAccessMemory instance = PhotoAccessMemory();

  final Map<String, bool>? _store;

  Future<bool> hasGranted() async {
    if (_store != null) return _store[prefsKey] == true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) == true;
  }

  Future<void> markGranted() async {
    if (_store != null) {
      _store[prefsKey] = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }

  Future<void> clearGranted() async {
    if (_store != null) {
      _store.remove(prefsKey);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}

enum PhotoAccessChoice { limited, full, deny }

Future<PhotoAccessChoice?> showPhotoAccessDialog(BuildContext context) {
  return showGeneralDialog<PhotoAccessChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'photo-access',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _IosPermissionSheet(
        keyName: 'auth-photo-access-dialog',
        title: 'Приложение запрашивает доступ к Фото',
        actions: [
          (PhotoAccessChoice.limited, 'Ограниченный доступ'),
          (PhotoAccessChoice.full, 'Полный доступ'),
          (PhotoAccessChoice.deny, 'Не предоставлять'),
        ],
      );
    },
  );
}

Future<bool?> showCameraAccessDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'camera-access',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _IosPermissionSheet(
        keyName: 'auth-camera-access-dialog',
        title: 'Приложение запрашивает доступ к Камере',
        actions: [
          (true, 'Разрешить'),
          (false, 'Не разрешать'),
        ],
      );
    },
  );
}

/// Shows the in-app access sheet until the user grants, then requests OS
/// gallery and camera. Remembered grants skip the sheet.
Future<bool> ensurePhotoMediaAccess({
  required BuildContext context,
  required PhotoLibrary library,
  PhotoAccessMemory? memory,
}) async {
  final store = memory ?? PhotoAccessMemory.instance;
  if (await store.hasGranted()) {
    final ok = await requestGalleryAndCamera(library, limited: false);
    if (ok) return true;
    await store.clearGranted();
  }
  if (!context.mounted) return false;
  final choice = await showPhotoAccessDialog(context);
  if (!context.mounted) return false;
  if (choice == null || choice == PhotoAccessChoice.deny) return false;
  final ok = await requestGalleryAndCamera(
    library,
    limited: choice == PhotoAccessChoice.limited,
  );
  if (!ok) return false;
  await store.markGranted();
  return true;
}

Future<File?> pickCroppedAvatar({
  required BuildContext context,
  required PhotoLibrary library,
  PhotoAccessMemory? memory,
}) async {
  final allowed = await ensurePhotoMediaAccess(
    context: context,
    library: library,
    memory: memory,
  );
  if (!allowed || !context.mounted) return null;
  final picked = await Navigator.of(context).push<File>(
    MaterialPageRoute(
      builder: (context) => PhotoPickerScreen(library: library),
    ),
  );
  if (picked == null || !context.mounted) return null;
  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      builder: (context) => PhotoCropScreen(file: picked),
    ),
  );
}

class _IosPermissionSheet<T> extends StatelessWidget {
  const _IosPermissionSheet({
    required this.keyName,
    required this.title,
    required this.actions,
  });

  final String keyName;
  final String title;
  final List<(T, String)> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: DecoratedBox(
            key: ValueKey<String>(keyName),
            decoration: BoxDecoration(
              color: const Color(0xF8F2F2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      height: 22 / 17,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),
                for (var i = 0; i < actions.length; i++) ...[
                  const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFC6C6C8)),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(actions[i].$1),
                      child: Text(
                        actions[i].$2,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 17,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoPickerScreen extends StatefulWidget {
  const PhotoPickerScreen({super.key, required this.library});

  final PhotoLibrary library;

  @override
  State<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends State<PhotoPickerScreen> {
  var _items = <PhotoAssetItem>[];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.library.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _onCamera() async {
    final remembered = await PhotoAccessMemory.instance.hasGranted();
    if (!mounted) return;
    if (!remembered) {
      final allow = await showCameraAccessDialog(context);
      if (allow != true || !mounted) return;
    }
    final granted = await widget.library.requestCamera();
    if (!granted || !mounted) return;
    final file = await widget.library.capture();
    if (file != null && mounted) Navigator.of(context).pop(file);
  }

  Future<void> _onAsset(PhotoAssetItem item) async {
    final file = await widget.library.load(item);
    if (file != null && mounted) Navigator.of(context).pop(file);
  }

  Future<void> _onGallery() async {
    final file = await widget.library.pickFromGallery();
    if (file != null && mounted) Navigator.of(context).pop(file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF007AFF), fontSize: 17),
          ),
        ),
        title: Container(
          height: 32,
          width: 136,
          decoration: BoxDecoration(
            color: const Color(0x14767680),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(
            child: Text(
              'Photos',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 34,
              child: TextField(
                key: const ValueKey<String>('auth-photo-search'),
                decoration: InputDecoration(
                  hintText: 'Photos',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: const Color(0x1F767680),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    key: const ValueKey<String>('auth-photo-grid'),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _items.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          key: const ValueKey<String>('auth-photo-camera-tile'),
                          onTap: _onCamera,
                          child: const ColoredBox(
                            color: Color(0xFFE8E8ED),
                            child: Icon(Icons.photo_camera_outlined, size: 32),
                          ),
                        );
                      }
                      if (index == 1) {
                        return GestureDetector(
                          key: const ValueKey<String>('auth-photo-gallery-tile'),
                          onTap: _onGallery,
                          child: const ColoredBox(
                            color: Color(0xFFE8E8ED),
                            child: Icon(Icons.photo_library_outlined, size: 32),
                          ),
                        );
                      }
                      final item = _items[index - 2];
                      return _ThumbTile(
                        item: item,
                        library: widget.library,
                        onTap: () => _onAsset(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    required this.item,
    required this.library,
    required this.onTap,
  });

  final PhotoAssetItem item;
  final PhotoLibrary library;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: library.thumbnail(item),
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: onTap,
          child: snapshot.data == null
              ? const ColoredBox(color: Color(0xFFD8D8D8))
              : Image.memory(snapshot.data!, fit: BoxFit.cover),
        );
      },
    );
  }
}

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.file});

  final File file;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const _pixelRatio = 3.0;

  final _boundaryKey = GlobalKey();
  final _circleKey = GlobalKey();
  late final Uint8List _bytes;
  var _busy = false;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytesSync();
  }

  Offset _circlePosition(Size viewport, double cropSize) {
    final maxX = math.max(0.0, viewport.width - cropSize);
    final maxY = math.max(0.0, viewport.height - cropSize);
    final center = Offset(
      (viewport.width - cropSize) / 2,
      (viewport.height - cropSize) / 2,
    );
    return Offset(
      (center.dx + _drag.dx).clamp(0.0, maxX),
      (center.dy + _drag.dy).clamp(0.0, maxY),
    );
  }

  void _onCirclePan(DragUpdateDetails details, Size viewport, double cropSize) {
    setState(() {
      _drag += details.delta;
      final pos = _circlePosition(viewport, cropSize);
      final center = Offset(
        (viewport.width - cropSize) / 2,
        (viewport.height - cropSize) / 2,
      );
      _drag = pos - center;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final boundaryContext = _boundaryKey.currentContext;
      final circleContext = _circleKey.currentContext;
      final boundary =
          boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
      final circleBox = circleContext?.findRenderObject() as RenderBox?;
      final boundaryBox = boundaryContext?.findRenderObject() as RenderBox?;
      if (boundary == null || circleBox == null || boundaryBox == null) return;
      final full = await boundary.toImage(pixelRatio: _pixelRatio);
      final local = circleBox.localToGlobal(Offset.zero) -
          boundaryBox.localToGlobal(Offset.zero);
      final cropW = circleBox.size.width * _pixelRatio;
      final cropH = circleBox.size.height * _pixelRatio;
      final src = Rect.fromLTWH(
        local.dx * _pixelRatio,
        local.dy * _pixelRatio,
        cropW,
        cropH,
      );
      final dest = Rect.fromLTWH(0, 0, cropW, cropH);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.clipPath(Path()..addOval(dest));
      canvas.drawImageRect(full, src, dest, Paint()..isAntiAlias = true);
      final image = await recorder.endRecording().toImage(
        cropW.round(),
        cropH.round(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('auth-photo-crop'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.biggest;
                final cropSize = math.min(
                  280.0,
                  math.min(viewport.width, viewport.height) * 0.78,
                );
                final circlePos = _circlePosition(viewport, cropSize);
                final circleRect = circlePos & Size(cropSize, cropSize);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: InteractiveViewer(
                          panEnabled: false,
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox(
                            width: viewport.width,
                            height: viewport.height,
                            child: Image.memory(
                              _bytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                return const ColoredBox(color: Color(0xFF333333));
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CropOverlayPainter(
                            circle: circleRect,
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: circlePos.dx,
                      top: circlePos.dy,
                      child: GestureDetector(
                        key: const ValueKey<String>('auth-photo-crop-circle'),
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) =>
                            _onCirclePan(details, viewport, cropSize),
                        child: SizedBox(
                          key: _circleKey,
                          width: cropSize,
                          height: cropSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: FilledButton(
                onPressed: _busy ? null : _save,
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
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.circle, required this.color});

  final Rect circle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circle);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.circle != circle || oldDelegate.color != color;
  }
}
