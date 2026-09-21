import 'package:flutter/foundation.dart';

/// Даты и гости текущего поиска. Вкладка «Избранное» считает по ним
/// строку дат и сумму на карточке — в коллекции `favorites` дат нет.
@immutable
class ActiveSearchStay {
  const ActiveSearchStay({
    this.checkIn,
    this.checkOut,
    this.adults = 0,
    this.children = 0,
    this.pets = 0,
  });

  final DateTime? checkIn;
  final DateTime? checkOut;
  final int adults;
  final int children;
  final int pets;

  static final current = ValueNotifier<ActiveSearchStay>(const ActiveSearchStay());

  static void publish({
    DateTime? checkIn,
    DateTime? checkOut,
    int adults = 0,
    int children = 0,
    int pets = 0,
  }) {
    final next = ActiveSearchStay(
      checkIn: checkIn,
      checkOut: checkOut,
      adults: adults,
      children: children,
      pets: pets,
    );
    if (current.value == next) return;
    current.value = next;
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveSearchStay &&
        other.checkIn == checkIn &&
        other.checkOut == checkOut &&
        other.adults == adults &&
        other.children == children &&
        other.pets == pets;
  }

  @override
  int get hashCode => Object.hash(checkIn, checkOut, adults, children, pets);
}
