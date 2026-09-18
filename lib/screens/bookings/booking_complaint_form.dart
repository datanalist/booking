import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../data/tickets_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _fieldFill = Color.fromRGBO(251, 192, 40, 0.06);
const _fieldStroke = Color.fromRGBO(251, 192, 40, 0.17);

const kComplaintTextLimit = 500;
const kComplaintPhotoSlots = 4;

class BookingComplaintForm extends StatefulWidget {
  const BookingComplaintForm({
    super.key,
    required this.booking,
    required this.type,
    required this.textKey,
    required this.sendKey,
    required this.backKey,
    this.ticketsRepository,
    this.photoLibrary,
  });

  final Booking booking;
  final TicketType type;
  final String textKey;
  final String sendKey;
  final String backKey;
  final TicketsRepository? ticketsRepository;
  final PhotoLibrary? photoLibrary;

  @override
  State<BookingComplaintForm> createState() => _BookingComplaintFormState();
}

class _BookingComplaintFormState extends State<BookingComplaintForm> {
  final _controller = TextEditingController();
  final _photos = <File>[];
  var _busy = false;
  String? _error;

  TicketsRepository get _tickets =>
      widget.ticketsRepository ?? TicketsRepositoryScope.instance;

  PhotoLibrary get _photosLib => widget.photoLibrary ?? DevicePhotoLibrary();

  bool get _canSend => _controller.text.trim().isNotEmpty && !_busy;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= kComplaintPhotoSlots || _busy) return;
    try {
      final file = await _photosLib.pickFromGallery();
      if (!mounted || file == null) return;
      setState(() => _photos.add(file));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось добавить изображение');
    }
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _tickets.create(
        type: widget.type,
        booking: widget.booking,
        text: _controller.text,
        photos: List<File>.from(_photos),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TicketException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Не удалось отправить жалобу';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.text.characters.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _fieldStroke),
          ),
          child: SizedBox(
            height: 160,
            child: TextField(
              key: ValueKey<String>(widget.textKey),
              controller: _controller,
              maxLength: kComplaintTextLimit,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              inputFormatters: [
                LengthLimitingTextInputFormatter(kComplaintTextLimit),
              ],
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.45,
                color: _ink,
              ),
              decoration: const InputDecoration(
                hintText: 'Опишите свою проблему',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  height: 1.45,
                  color: _meta,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$count/$kComplaintTextLimit',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.5,
              color: _meta,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Изображение',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF1F1E24),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < kComplaintPhotoSlots; i++)
              _PhotoSlot(
                key: ValueKey<String>('complaint-photo-$i'),
                file: i < _photos.length ? _photos[i] : null,
                onTap: _pickPhoto,
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.4,
              color: Color(0xFFC23B2A),
            ),
          ),
        ],
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey<String>(widget.backKey),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
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
                child: const Text('Вернуться'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: ValueKey<String>(widget.sendKey),
                onPressed: _canSend ? _submit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: const Color(0x66F88A2A),
                  disabledForegroundColor: AppColors.white,
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Отправить'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({super.key, required this.onTap, this.file});

  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: file == null ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _fieldStroke, style: BorderStyle.solid),
          ),
          child: SizedBox(
            width: 80,
            height: 80,
            child: file == null
                ? Center(
                    child: SvgPicture.asset(
                      'images/bookings/complaint-plus-24.svg',
                      width: 24,
                      height: 24,
                      excludeFromSemantics: true,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(file!, fit: BoxFit.cover),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Общая оболочка боттомшита жалобы (Figma `1:11623` / `1:11726`).
Future<bool?> showComplaintSheet({
  required BuildContext context,
  required String sheetKey,
  required String title,
  required Widget header,
  required BookingComplaintForm form,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: const Color(0xFF525353),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        key: ValueKey<String>(sheetKey),
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      height: 1.2,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                header,
                const SizedBox(height: 40),
                form,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 5,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(251, 192, 40, 0.17),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
