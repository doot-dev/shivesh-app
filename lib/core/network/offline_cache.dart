import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Offline copy of every successful GET, in SQLite.
///
/// One table: key = the request URL (with its query), body = the JSON the
/// server sent. When the phone has no network, the same GET is answered from
/// here, so the app opens offline and every screen shows what it last showed.
/// Writes (placing an order, comments) still need the network.
///
/// ponytail: whole responses per URL, not a table per entity. Screens already
/// parse these bodies, so nothing else has to change. Normalise only if a
/// screen ever needs to query saved data in a new way.
class OfflineCache {
  OfflineCache._();

  static Future<Database>? _db;

  static Future<Database> _open() => _db ??= getDatabasesPath().then(
    (dir) => openDatabase(
      '$dir/api_cache.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE cache (key TEXT PRIMARY KEY, body TEXT NOT NULL, savedAt INTEGER NOT NULL)',
      ),
    ),
  );

  static Future<void> put(String key, Object? body) async {
    final db = await _open();
    await db.insert('cache', {
      'key': key,
      'body': jsonEncode(body),
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Object?> get(String key) async {
    final db = await _open();
    final rows = await db.query(
      'cache',
      columns: ['body'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['body']! as String);
  }

  /// On logout and login: one person's saved data must never show to the next.
  static Future<void> clear() async {
    final db = await _open();
    await db.delete('cache');
  }
}

/// True while screens are showing saved data because the network is down.
final offlineNotifier = ValueNotifier<bool>(false);

class OfflineCacheInterceptor extends Interceptor {
  static bool _isNetworkDown(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      (e.type == DioExceptionType.unknown && e.error is SocketException);

  static String _key(RequestOptions o) => o.uri.toString();

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final o = response.requestOptions;
    if (o.method == 'GET' && (response.data is Map || response.data is List)) {
      offlineNotifier.value = false;
      try {
        await OfflineCache.put(_key(o), response.data);
      } catch (e) {
        debugPrint(
          'OfflineCache put failed: $e',
        ); // never break a live response
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final o = err.requestOptions;
    if (o.method == 'GET' && _isNetworkDown(err)) {
      final saved = await OfflineCache.get(_key(o)).catchError((_) => null);
      if (saved != null) {
        offlineNotifier.value = true;
        return handler.resolve(
          Response(
            requestOptions: o,
            data: saved,
            statusCode: 200,
            extra: {'fromCache': true},
          ),
        );
      }
    }
    handler.next(err);
  }
}
