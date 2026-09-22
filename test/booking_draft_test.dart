import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking_draft.dart';

void main() {
  test('memory store keeps listing stay dates and guests', () async {
    final store = BookingDraftStore.memory();
    const listingId = 'studio-msk';
    final checkIn = DateTime(2026, 9, 12);
    final checkOut = DateTime(2026, 9, 15);

    expect(await store.load(listingId: listingId), isNull);

    await store.save(
      BookingDraft(
        listingId: listingId,
        checkIn: checkIn,
        checkOut: checkOut,
        adults: 2,
        children: 1,
        pets: 1,
      ),
    );

    final loaded = await store.load(listingId: listingId);
    expect(loaded, isNotNull);
    expect(loaded!.listingId, listingId);
    expect(loaded.checkIn, checkIn);
    expect(loaded.checkOut, checkOut);
    expect(loaded.adults, 2);
    expect(loaded.children, 1);
    expect(loaded.pets, 1);
  });

  test('draft for another listing is ignored', () async {
    final store = BookingDraftStore.memory(
      BookingDraft(
        listingId: 'studio-msk',
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
      ),
    );

    expect(await store.load(listingId: 'old-town'), isNull);
    expect(await store.load(listingId: 'studio-msk'), isNotNull);
  });

  test('invalid or inverted dates do not parse', () {
    expect(BookingDraft.fromJson(null), isNull);
    expect(BookingDraft.fromJson({'listingId': ''}), isNull);
    expect(
      BookingDraft.fromJson({
        'listingId': 'studio-msk',
        'checkIn': '2026-09-15',
        'checkOut': '2026-09-15',
      }),
      isNull,
    );
  });

  test('legacy date-only drafts default guests to one adult', () {
    final draft = BookingDraft.fromJson({
      'listingId': 'studio-msk',
      'checkIn': '2026-09-12',
      'checkOut': '2026-09-15',
    });

    expect(draft, isNotNull);
    expect(draft!.adults, 1);
    expect(draft.children, 0);
    expect(draft.pets, 0);
  });

  test('guest counts are clamped to search stepper bounds', () {
    final draft = BookingDraft.fromJson({
      'listingId': 'studio-msk',
      'checkIn': '2026-09-12',
      'checkOut': '2026-09-15',
      'adults': 0,
      'children': -2,
      'pets': '99',
    });

    expect(draft, isNotNull);
    expect(draft!.adults, StayGuests.minAdults);
    expect(draft.children, StayGuests.minChildren);
    expect(draft.pets, StayGuests.maxCount);
  });

  test('copyWith can lock pets when the listing forbids them', () {
    final draft = BookingDraft(
      listingId: 'studio-msk',
      checkIn: DateTime(2026, 9, 12),
      checkOut: DateTime(2026, 9, 15),
      adults: 2,
      pets: 2,
    ).copyWith(petsAllowed: false);

    expect(draft.pets, 0);
    expect(draft.adults, 2);
  });
}
