import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interview_fallback.dart';

/// Calls the FastAPI copilot server ([POST /interview/suggest](https://platform.openai.com/docs/guides/text))
/// which uses `OPENAI_API_KEY` on the machine running the backend — not embedded in the mobile app.
class BackendAnswerService {
  BackendAnswerService({
    required this.baseUrl,
    this.client,
    this.timeout = const Duration(seconds: 40),
  });

  final String baseUrl;
  final http.Client? client;
  final Duration timeout;

  Uri _suggestUri() {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$trimmed/interview/suggest');
  }

  Future<String> generate({
    required String question,
    required List<String> retrievedChunks,
    required List<String> shortMemory,
  }) async {
    final uri = _suggestUri();
    final payload = jsonEncode({
      'question': question,
      'retrieved': retrievedChunks,
      'short_memory': shortMemory,
    });
    final c = client ?? http.Client();
    try {
      final resp = await c
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: payload,
          )
          .timeout(timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Copilot server ${resp.statusCode}: ${resp.body}');
      }
      final map = jsonDecode(utf8.decode(resp.bodyBytes));
      if (map is! Map<String, dynamic>) {
        throw Exception('Invalid JSON from copilot server');
      }
      final text = (map['text'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        throw Exception('Empty text in copilot server response');
      }
      return text;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Copilot server request failed: $e');
    } finally {
      if (client == null) {
        c.close();
      }
    }
  }
}
