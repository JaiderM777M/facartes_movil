import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

SupabaseClient get _sb => Supabase.instance.client;

/// Acceso a datos (Supabase). Todo lo que toca la red vive aquí.
class Repo {
  static String get uid => _sb.auth.currentUser!.id;
  static String get displayName =>
      (_sb.auth.currentUser?.userMetadata?['name'] as String?) ?? 'Artista';

  /// URL de la foto de perfil del usuario actual.
  static final avatar = ValueNotifier<String?>(null);

  /// Ruta dentro del bucket a partir de la URL pública.
  static String? _storagePath(String? url) {
    if (url == null) return null;
    const marker = '/artworks/';
    final i = url.indexOf(marker);
    return i >= 0 ? url.substring(i + marker.length) : null;
  }

  static Future<void> refresh() async {
    final me = await _sb.from('profiles').select('avatar_url').eq('id', uid).maybeSingle();
    avatar.value = me?['avatar_url'] as String?;

    final rows = await _sb
        .from('artworks')
        .select('*, profiles!artworks_user_id_fkey(name, dept, avatar_url), likes(count)')
        .order('created_at', ascending: false);
    final liked = (await _sb.from('likes').select('artwork_id').eq('user_id', uid))
        .map((r) => r['artwork_id'] as String)
        .toSet();
    final saved = (await _sb.from('saves').select('artwork_id').eq('user_id', uid))
        .map((r) => r['artwork_id'] as String)
        .toSet();
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
    required Uint8List bytes,
    required String mime,
    required String title,
    required String desc,
    required String category,
    required String technique,
    required String year,
    required String dims,
    required List<String> tags,
  }) async {
    final ext = mime.contains('png') ? 'png' : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage.from('artworks').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    final url = _sb.storage.from('artworks').getPublicUrl(path);
    String? n(String s) => s.isEmpty ? null : s;
    await _sb.from('artworks').insert({
      'user_id': uid,
      'title': title,
      'description': n(desc),
      'category': category,
      'technique': n(technique),
      'year': n(year),
      'dimensions': n(dims),
      'tags': tags,
      'image_url': url,
    });
    await refresh();
  }

  /// Borra la obra (solo la tuya, por RLS) y su imagen del almacenamiento.
  static Future<void> deleteArtwork(Artwork a) async {
    final path = _storagePath(a.imageUrl);
    await _sb.from('artworks').delete().eq('id', a.id);
    if (path != null) {
      try {
        await _sb.storage.from('artworks').remove([path]);
      } catch (_) {}
    }
    await refresh();
  }

  /// Sube una foto de perfil nueva y borra la anterior.
  static Future<void> updateAvatar(Uint8List bytes, String mime) async {
    final ext = mime.contains('png') ? 'png' : 'jpg';
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage.from('artworks').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    final url = _sb.storage.from('artworks').getPublicUrl(path);
    final oldPath = _storagePath(avatar.value);
    await _sb.from('profiles').update({'avatar_url': url}).eq('id', uid);
    avatar.value = url;
    if (oldPath != null) {
      try {
        await _sb.storage.from('artworks').remove([oldPath]);
      } catch (_) {}
    }
    await refresh();
  }

  static Future<void> signOut() async {
    artworks.value = [];
    avatar.value = null;
    await _sb.auth.signOut();
  }
}