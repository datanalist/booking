import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

class DevicePhotoLibrary implements PhotoLibrary {
  DevicePhotoLibrary({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<bool> requestGallery({required bool limited}) async {
    final status = await Permission.photos.request();
    return status.isGranted ||
        status.isLimited ||
        status.isDenied ||
        status.isRestricted;
  }

  @override
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
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
    final allow = await showCameraAccessDialog(context);
    if (allow != true || !mounted) return;
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
  final _boundaryKey = GlobalKey();
  var _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final context = _boundaryKey.currentContext;
      final boundary = context?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      Navigator.of(this.context).pop(file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: ClipOval(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(widget.file, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
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
