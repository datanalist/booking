import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking_draft.dart';

void main() {
  test('memory store keeps listing stay dates', () async {
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
      ),
    );

    final loaded = await store.load(listingId: listingId);
    expect(loaded, isNotNull);
    expect(loaded!.listingId, listingId);
    expect(loaded.checkIn, checkIn);
    expect(loaded.checkOut, checkOut);
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
}
