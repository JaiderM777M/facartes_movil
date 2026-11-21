import 'dart:typed_data';

class AiResult {
  final List<String> tags;
  final String category, description;
  const AiResult({required this.tags, required this.category, required this.description});
  static const empty = AiResult(tags: [], category: 'Otro', description: '');
}

class AiService {
  /// FASE 2: reemplazar por llamada a una Edge Function de Supabase que use Gemini.
  /// Por ahora devuelve un resultado simulado.
  static Future<AiResult> analyze(Uint8List bytes, String mime) async {
    await Future.delayed(const Duration(seconds: 2));
    return const AiResult(
      tags: ['Pintura', 'Óleo', 'Paisaje', 'Realismo', 'Montaña', 'Arquitectura'],
      category: 'Pintura',
      description: 'Descripción simulada (la IA real se conecta en la Fase 2).',
    );
  }
}
