import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiGatewayService {
  const AiGatewayService({
    required this.gatewayUrl,
    required this.huggingFaceToken,
  });

  final String gatewayUrl;
  final String huggingFaceToken;

  Uri get _apiUri {
    final uri = Uri.parse(gatewayUrl);
    if (uri.scheme != 'https') {
      debugPrint('WARNING: AI gateway URL is not HTTPS — security risk');
    }
    return Uri.parse('$gatewayUrl/api/ai/analyze');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (huggingFaceToken.isNotEmpty)
          'Authorization': 'Bearer $huggingFaceToken',
      };

  bool get isEnabled => gatewayUrl.isNotEmpty && huggingFaceToken.isNotEmpty;

  /// Returns (isToxic, explanation).
  Future<(bool, String)> analyzeToxicity(String text) async {
    if (!isEnabled) {
      return (false, '');
    }

    try {
      final response = await http
          .post(
            _apiUri,
            headers: _headers,
            body: jsonEncode({'input': text, 'task': 'toxicity'}),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode >= 400) {
        return (false, '');
      }

      final decoded = jsonDecode(response.body);
      // HF returns a nested array: [[{label, score}, ...]]
      // Backend may wrap it in AiResponse.result as a string
      final String rawJson;
      if (decoded is Map && decoded['result'] is String) {
        rawJson = decoded['result'] as String;
      } else {
        rawJson = response.body;
      }

      final List<dynamic> predictions;
      final parsed = jsonDecode(rawJson);
      if (parsed is List && parsed.isNotEmpty && parsed.first is List) {
        predictions = parsed.first as List<dynamic>;
      } else if (parsed is List) {
        predictions = parsed;
      } else {
        return (false, '');
      }

      for (final p in predictions) {
        if (p is Map && p['label']?.toString().toLowerCase() == 'toxic') {
          final score = (p['score'] as num?)?.toDouble() ?? 0.0;
          if (score > 0.7) {
            return (true, 'Message jugé inapproprié par la modération IA.');
          }
        }
      }
      return (false, '');
    } catch (e) {
      debugPrint('AiGatewayService.analyzeToxicity error: $e');
      return (false, '');
    }
  }

  Future<String> recommendTeammates() async {
    if (!isEnabled) {
      return '';
    }
    try {
      final response = await http
          .post(
            _apiUri,
            headers: _headers,
            body: jsonEncode({'task': 'recommendation'}),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode >= 400) {
        return '';
      }
      final body = response.body.trim();
      if (body.isEmpty) return '';

      final decoded = jsonDecode(body);
      final String innerJson;
      if (decoded is Map && decoded['result'] is String) {
        innerJson = decoded['result'] as String;
      } else {
        return '';
      }

      final inner = jsonDecode(innerJson);
      if (inner is! Map) return '';

      final recommendations = inner['recommendations'];
      if (recommendations is! List || recommendations.isEmpty) return '';

      return 'Recommandations IA: ${recommendations.join(', ')}';
    } catch (e) {
      debugPrint('AiGatewayService.recommendTeammates error: $e');
      return '';
    }
  }
}
