import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

SupabaseClient get _sb => Supabase.instance.client;

/// Acceso a datos (Supabase). Todo lo que toca la red vive aquí.
class Repo {
  static String get uid => _sb.auth.currentUser!.id;
  static String get displayName =>
      (_sb.auth.currentUser?.userMetadata?['name'] as String?) ?? 'Artista';

  static Future<void> refresh() async {
    final rows = await _sb
        .from('artworks')
        .select('*, profiles!artworks_user_id_fkey(name, dept), likes(count)')
        .order('created_at', ascending: false);
    final liked = (await _sb.from('likes').select('artwork_id').eq('user_id', uid))
        .map((r) => r['artwork_id'] as String).toSet();
    final saved = (await _sb.from('saves').select('artwork_id').eq('user_id', uid))
        .map((r) => r['artwork_id'] as String).toSet();
    artworks.value = rows
        .map((m) => Artwork.fromMap(m, liked: liked.contains(m['id']), saved: saved.contains(m['id'])))
        .toList();
  }

  static Future<void> toggleLike(Artwork a) async {
    final on = !a.liked;
    a.liked = on;
    a.likes += on ? 1 : -1;
    try {
      if (on) {
        await _sb.from('likes').insert({'user_id': uid, 'artwork_id': a.id});
      } else {
        await _sb.from('likes').delete().eq('user_id', uid).eq('artwork_id', a.id);
      }
    } catch (_) {
      a.liked = !on;
      a.likes += on ? -1 : 1;
      rethrow;
    }
  }

  static Future<void> toggleSave(Artwork a) async {
    final on = !a.saved;
    a.saved = on;
    try {
      if (on) {
        await _sb.from('saves').insert({'user_id': uid, 'artwork_id': a.id});
      } else {
        await _sb.from('saves').delete().eq('user_id', uid).eq('artwork_id', a.id);
      }
    } catch (_) {
      a.saved = !on;
      rethrow;
    }
  }

  static Future<void> publish({
    required Uint8List bytes, required String mime, required String title,
    required String desc, required String category, required String technique,
    required String year, required String dims, required List<String> tags,
  }) async {
    final ext = mime.contains('png') ? 'png' : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage.from('artworks').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    final url = _sb.storage.from('artworks').getPublicUrl(path);
    String? n(String s) => s.isEmpty ? null : s;
    await _sb.from('artworks').insert({
      'user_id': uid, 'title': title, 'description': n(desc), 'category': category,
      'technique': n(technique), 'year': n(year), 'dimensions': n(dims),
      'tags': tags, 'image_url': url,
    });
    await refresh();
  }

  static Future<void> signOut() async {
    artworks.value = [];
    await _sb.auth.signOut();
  }
}
