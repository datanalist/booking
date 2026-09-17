import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local stay-date draft for the booking flow. Never written to PocketBase.
@immutable
class BookingDraft {
  const BookingDraft({
    required this.listingId,
    required this.checkIn,
    required this.checkOut,
  });

  final String listingId;
  final DateTime checkIn;
  final DateTime checkOut;

  Map<String, String> toJson() => {
    'listingId': listingId,
    'checkIn': formatDraftDate(checkIn),
    'checkOut': formatDraftDate(checkOut),
  };

  static BookingDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final listingId = json['listingId']?.toString() ?? '';
    final checkIn = parseDraftDate(json['checkIn']?.toString());
    final checkOut = parseDraftDate(json['checkOut']?.toString());
    if (listingId.isEmpty || checkIn == null || checkOut == null) return null;
    if (!checkOut.isAfter(checkIn)) return null;
    return BookingDraft(
      listingId: listingId,
      checkIn: checkIn,
      checkOut: checkOut,
    );
  }
}

String formatDraftDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseDraftDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Device-only booking draft (listing + stay dates) beside `pb_auth`.
class BookingDraftStore {
  BookingDraftStore({Map<String, String>? store}) : _store = store;

  /// In-memory store for widget tests (avoids the SharedPreferences plugin).
  factory BookingDraftStore.memory([BookingDraft? initial]) {
    final store = <String, String>{};
    if (initial != null) {
      store[prefsKey] = jsonEncode(initial.toJson());
    }
    return BookingDraftStore(store: store);
  }

  /// Prefs key beside `pb_auth`.
  static const prefsKey = 'booking_draft';

  static BookingDraftStore instance = BookingDraftStore();

  final Map<String, String>? _store;

  Future<BookingDraft?> load({String? listingId}) async {
    final raw = await _read();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = BookingDraft.fromJson(Map<String, dynamic>.from(decoded));
      if (draft == null) return null;
      if (listingId != null && draft.listingId != listingId) return null;
      return draft;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(BookingDraft draft) async {
    final encoded = jsonEncode(draft.toJson());
    if (_store != null) {
      _store[prefsKey] = encoded;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, encoded);
  }

  Future<void> clear() async {
    if (_store != null) {
      _store.remove(prefsKey);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  Future<String?> _read() async {
    if (_store != null) return _store[prefsKey];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKey);
  }
}
