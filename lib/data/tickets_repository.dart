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
    this.chatId = '',
    this.assigneeId = '',
    this.refundAmount = 0,
    this.photos = const [],
    this.created,
  });

  final String id;
  final String authorId;
  final TicketType type;
  final String text;
  final String listingId;
  final String hostId;
  final String bookingId;
  final String chatId;
  final String assigneeId;
  final double refundAmount;
  final List<String> photos;
  final DateTime? created;
}

class TicketException implements Exception {
  const TicketException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class TicketsRepository {
  Future<List<SupportTicket>> listMine();

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
  Future<List<SupportTicket>> listMine() async {
    final authorId = _userId;
    if (authorId.isEmpty || !_pb.authStore.isValid) return const [];
    try {
      final records = await _pb.collection(collection).getFullList(
        filter: pbFilter('author = {:authorId}', {'authorId': authorId}),
        sort: '-created',
      );
      return [for (final record in records) _map(record)];
    } on ClientException catch (error) {
      throw TicketException(_messageFor(error));
    }
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
    final body = <String, dynamic>{
      'author': authorId,
      'type': type.apiKey,
      'text': trimmed,
    };
    if (booking.listingId.isNotEmpty) {
      body['listing'] = booking.listingId;
    }
    if (booking.hostId.isNotEmpty) {
      body['host'] = booking.hostId;
    }
    if (booking.id.isNotEmpty) {
      body['booking'] = booking.id;
    }
    try {
      final record = await _pb
          .collection(collection)
          .create(body: body, files: files);
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
      chatId: record.get<String>('chat', ''),
      assigneeId: record.get<String>('assignee', ''),
      refundAmount: _number(record, 'refund_amount'),
      photos: _fileUrls(record, 'photos'),
      created: DateTime.tryParse(record.get<String>('created', '')),
    );
  }

  List<String> _fileUrls(RecordModel record, String field) {
    final raw = record.data[field] ?? record.get<dynamic>(field);
    if (raw is! List || raw.isEmpty) return const [];
    final base = _pb.baseURL;
    return [
      for (final name in raw)
        if (name is String && name.isNotEmpty)
          '$base/api/files/$collection/${record.id}/$name',
    ];
  }

  double _number(RecordModel record, String field) {
    final raw = record.data.containsKey(field)
        ? record.data[field]
        : record.get<dynamic>(field);
    if (raw is num) return raw.toDouble();
    if (raw == null) return 0;
    return double.tryParse('$raw') ?? 0;
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось отправить жалобу';
  }
}
