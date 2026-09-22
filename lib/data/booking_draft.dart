import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guest counts for the local booking draft. Same bounds as search steppers.
@immutable
class StayGuests {
  const StayGuests({
    required this.adults,
    required this.children,
    required this.pets,
  });

  static const minAdults = 1;
  static const minChildren = 0;
  static const minPets = 0;
  static const maxCount = 16;

  final int adults;
  final int children;
  final int pets;

  factory StayGuests.normalized({
    int adults = minAdults,
    int children = minChildren,
    int pets = minPets,
    bool petsAllowed = true,
  }) {
    return StayGuests(
      adults: adults.clamp(minAdults, maxCount),
      children: children.clamp(minChildren, maxCount),
      pets: petsAllowed ? pets.clamp(minPets, maxCount) : minPets,
    );
  }
}

/// Local stay-date + guests draft for the booking flow. Never written to PocketBase.
@immutable
class BookingDraft {
  const BookingDraft({
    required this.listingId,
    required this.checkIn,
    required this.checkOut,
    this.adults = StayGuests.minAdults,
    this.children = StayGuests.minChildren,
    this.pets = StayGuests.minPets,
  });

  final String listingId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int adults;
  final int children;
  final int pets;

  StayGuests get guests =>
      StayGuests.normalized(adults: adults, children: children, pets: pets);

  BookingDraft copyWith({
    String? listingId,
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    int? pets,
    bool petsAllowed = true,
  }) {
    final next = StayGuests.normalized(
      adults: adults ?? this.adults,
      children: children ?? this.children,
      pets: pets ?? this.pets,
      petsAllowed: petsAllowed,
    );
    return BookingDraft(
      listingId: listingId ?? this.listingId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      adults: next.adults,
      children: next.children,
      pets: next.pets,
    );
  }

  Map<String, dynamic> toJson() => {
    'listingId': listingId,
    'checkIn': formatDraftDate(checkIn),
    'checkOut': formatDraftDate(checkOut),
    'adults': adults,
    'children': children,
    'pets': pets,
  };

  static BookingDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final listingId = json['listingId']?.toString() ?? '';
    final checkIn = parseDraftDate(json['checkIn']?.toString());
    final checkOut = parseDraftDate(json['checkOut']?.toString());
    if (listingId.isEmpty || checkIn == null || checkOut == null) return null;
    if (!checkOut.isAfter(checkIn)) return null;
    final guests = StayGuests.normalized(
      adults: _readCount(json['adults'], StayGuests.minAdults),
      children: _readCount(json['children'], StayGuests.minChildren),
      pets: _readCount(json['pets'], StayGuests.minPets),
    );
    return BookingDraft(
      listingId: listingId,
      checkIn: checkIn,
      checkOut: checkOut,
      adults: guests.adults,
      children: guests.children,
      pets: guests.pets,
    );
  }

  static int _readCount(Object? raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
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

/// Device-only booking draft (listing + stay dates + guests) beside `pb_auth`.
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
