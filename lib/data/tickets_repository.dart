import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'auth_repository.dart';
import 'booking.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

enum TicketType {
  support('support'),
  listing('listing'),
  host('host'),
  booking('booking');

  const TicketType(this.apiKey);

  final String apiKey;

  static TicketType fromApi(String value) {
    for (final type in TicketType.values) {
      if (type.apiKey == value) return type;
    }
    return TicketType.support;
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.authorId,
    required this.type,
    required this.text,
    this.listingId = '',
    this.hostId = '',
    this.bookingId = '',
    this.photos = const [],
  });

  final String id;
  final String authorId;
  final TicketType type;
  final String text;
  final String listingId;
  final String hostId;
  final String bookingId;
  final List<String> photos;
}

class TicketException implements Exception {
  const TicketException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class TicketsRepository {
  Future<SupportTicket> create({
    required TicketType type,
    required Booking booking,
    required String text,
    List<File> photos = const [],
  });
}

class TicketsRepositoryScope {
  static TicketsRepository instance = PocketBaseTicketsRepository();
}

class PocketBaseTicketsRepository implements TicketsRepository {
  PocketBaseTicketsRepository({this._client});

  static const collection = PbCollection.tickets;

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  @override
  Future<SupportTicket> create({
    required TicketType type,
    required Booking booking,
    required String text,
    List<File> photos = const [],
  }) async {
    final authorId = _userId;
    if (authorId.isEmpty) {
      throw const TicketException('Войдите, чтобы отправить жалобу');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const TicketException('Опишите свою проблему');
    }
    final files = <http.MultipartFile>[];
    for (var i = 0; i < photos.length; i++) {
      files.add(
        http.MultipartFile.fromBytes(
          'photos',
          await photos[i].readAsBytes(),
          filename: 'complaint-$i.jpg',
        ),
      );
    }
    try {
      final record = await _pb
          .collection(collection)
          .create(
            body: {
              'author': authorId,
              'type': type.apiKey,
              'listing': booking.listingId,
              'host': booking.hostId,
              'booking': booking.id,
              'text': trimmed,
            },
            files: files,
          );
      return _map(record);
    } on ClientException catch (error) {
      throw TicketException(_messageFor(error));
    }
  }

  SupportTicket _map(RecordModel record) {
    return SupportTicket(
      id: record.id,
      authorId: record.get<String>('author', ''),
      type: TicketType.fromApi(record.get<String>('type', '')),
      text: record.get<String>('text', ''),
      listingId: record.get<String>('listing', ''),
      hostId: record.get<String>('host', ''),
      bookingId: record.get<String>('booking', ''),
    );
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось отправить жалобу';
  }
}
