import 'dart:convert';
import 'dart:io';

class IoHttpResponse {
  const IoHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  Map<String, dynamic>? get jsonObject {
    if (body.isEmpty) {
      return null;
    }
    final value = jsonDecode(body);
    return value is Map<String, dynamic> ? value : null;
  }
}

class IoHttp {
  static Future<IoHttpResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Object? jsonBody,
    bool allowBadCertificate = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;

    if (allowBadCertificate) {
      client.badCertificateCallback = (_, __, ___) => true;
    }

    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(jsonBody));
      }

      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);
      return IoHttpResponse(statusCode: response.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }
}
