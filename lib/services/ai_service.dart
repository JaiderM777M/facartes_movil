import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiResult {
  final List<String> tags;
  final String category, description;
  const AiResult({required this.tags, required this.category, required this.description});
  static const empty = AiResult(tags: [], category: 'Otro', description: '');
}

class AiService {
  /// Llama a la Edge Function `analyze-artwork`, que consulta Gemini.
  static Future<AiResult> analyze(Uint8List bytes, String mime) async {
    final res = await Supabase.instance.client.functions.invoke(
      'analyze-artwork',
      body: {'image': base64Encode(bytes), 'mime': mime},
    );
    final d = Map<String, dynamic>.from(res.data as Map);
    return AiResult(
      tags: List<String>.from(d['tags'] ?? const []),
      category: (d['category'] as String?) ?? 'Otro',
      description: (d['description'] as String?) ?? '',
    );
  }
}