import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// URL del backend. Se define al compilar:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1/
/// Por defecto apunta al servidor local visto desde el emulador de Android.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1/',
  );
}

/// No hay conexion con el backend (sin internet, servidor apagado o tiempo
/// de espera agotado). Los cambios quedan pendientes en el telefono.
class OfflineException implements Exception {
  const OfflineException([this.cause]);
  final Object? cause;
  @override
  String toString() => 'Sin conexión con el servidor';
}

/// El backend respondio con un error.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.body);
  final int status;
  final String code;
  final Map<String, dynamic>? body;

  /// Version guardada en el backend cuando gana el ultimo cambio (409).
  Map<String, dynamic>? get current => body?['actual'] as Map<String, dynamic>?;

  @override
  String toString() => 'ApiException($status, $code)';
}

typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// Cliente HTTPS/REST del backend Django (OB2: integracion app - backend).
class ApiClient {
  ApiClient({
    required TokenProvider token,
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 75),
  })  : _token = token,
        _base = Uri.parse(baseUrl ?? ApiConfig.baseUrl),
        _http = client ?? http.Client();

  final TokenProvider _token;
  final Uri _base;
  final http.Client _http;

  /// Amplio: el plan gratuito de Render tarda en despertar el servicio.
  final Duration timeout;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> put(String path, Object body, {Map<String, String>? query}) =>
      _send('PUT', path, body: body, query: query);

  Future<dynamic> post(String path, Object body) =>
      _send('POST', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Envia un archivo (bytes) en el cuerpo, por ejemplo una imagen.
  Future<dynamic> putBytes(String path, Uint8List bytes,
          {Map<String, String>? query}) =>
      _send('PUT', path, body: bytes, query: query);

  /// Descarga un archivo; null si no existe (404).
  Future<Uint8List?> getBytes(String path) async {
    try {
      return await _send('GET', path, raw: true) as Uint8List;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool raw = false,
  }) async {
    var response = await _request(method, path, body, query, refresh: false);
    if (response.statusCode == 401) {
      // Token vencido: se renueva una vez.
      response = await _request(method, path, body, query, refresh: true);
    }
    if (raw && response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final map = decoded is Map<String, dynamic> ? decoded : null;
    final error = map?['error'];
    final code = error is Map ? '${error['codigo']}' : 'error';
    throw ApiException(response.statusCode, code, map);
  }

  Future<http.Response> _request(
    String method,
    String path,
    Object? body,
    Map<String, String>? query, {
    required bool refresh,
  }) async {
    final String? token;
    try {
      token = await _token(forceRefresh: refresh);
    } catch (e) {
      throw OfflineException(e);
    }
    if (token == null) throw ApiException(401, 'sin_sesion', null);
    final uri = _base.resolve(path).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (body is Uint8List) {
      request.headers['Content-Type'] = 'application/octet-stream';
      request.bodyBytes = body;
    } else if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on SocketException catch (e) {
      throw OfflineException(e);
    } on TimeoutException catch (e) {
      throw OfflineException(e);
    } on http.ClientException catch (e) {
      throw OfflineException(e);
    } on HandshakeException catch (e) {
      throw OfflineException(e);
    }
  }
}
