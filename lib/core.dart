import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kPrimary = Color(0xFFC25B34);
const kBg = Color(0xFFFAF5EC);
const kInk = Color(0xFF2B2B2B);
const kMuted = Color(0xFF8A817A);

ThemeData buildTheme() {
  final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary, surface: kBg),
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg, elevation: 0, scrolledUnderElevation: 0,
      foregroundColor: kInk, centerTitle: false,
      titleTextStyle: TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kPrimary.withValues(alpha: .14),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white, border: border, enabledBorder: border,
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
      hintStyle: const TextStyle(color: kMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary, minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class Artwork {
  final String id, userId, title, artist, dept, technique, year, size, desc, category, imageUrl;
  final List<String> tags;
  final String? artistAvatar;
  int likes;
  bool liked, saved;
  Artwork({
    required this.id, required this.userId, required this.title, required this.artist,
    required this.dept, required this.technique, required this.year, required this.size,
    required this.desc, required this.category, required this.imageUrl, required this.tags,
    this.artistAvatar, this.likes = 0, this.liked = false, this.saved = false,
  });

  bool get mine => userId == Supabase.instance.client.auth.currentUser?.id;

  factory Artwork.fromMap(Map<String, dynamic> m, {bool liked = false, bool saved = false}) {
    final p = (m['profiles'] as Map?) ?? {};
    final l = (m['likes'] as List?) ?? [];
    return Artwork(
      id: m['id'], userId: m['user_id'], title: m['title'] ?? '',
      artist: p['name'] ?? 'Anónimo', dept: p['dept'] ?? 'Artes Visuales',
      technique: m['technique'] ?? '—', year: m['year'] ?? '—', size: m['dimensions'] ?? '—',
      desc: m['description'] ?? '', category: m['category'] ?? '', imageUrl: m['image_url'] ?? '',
      tags: List<String>.from(m['tags'] ?? const []),
      likes: l.isEmpty ? 0 : (l.first['count'] as int),
      artistAvatar: p['avatar_url'] as String?,
      liked: liked, saved: saved,
    );
  }
}

/// Obras cargadas desde Supabase (se actualiza con Repo.refresh()).
final artworks = ValueNotifier<List<Artwork>>([]);

class ArtThumb extends StatelessWidget {
  final Artwork art;
  final double radius;
  const ArtThumb(this.art, {super.key, this.radius = 16});

  Widget _ph() => Container(
        color: const Color(0xFFE9DFD2),
        child: const Center(child: Icon(Icons.image_outlined, color: kMuted, size: 40)),
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          art.imageUrl,
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          errorBuilder: (_, __, ___) => _ph(),
          loadingBuilder: (_, child, p) => p == null ? child : _ph(),
        ),
      );
}

class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  const UserAvatar(this.url, {super.key, this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final u = url;
    final has = u != null && u.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE3C9B8),
      backgroundImage: has ? NetworkImage(u) : null,
      child: has ? null : Icon(Icons.person, color: Colors.white, size: radius * 1.1),
    );
  }
}

class AiBadge extends StatelessWidget {
  final String text;
  const AiBadge({super.key, this.text = 'Generado por IA'});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kPrimary.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 12, color: kPrimary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10.5, color: kPrimary, fontWeight: FontWeight.w600)),
        ]),
      );
}

class TagChip extends StatelessWidget {
  final String text;
  final int i;
  const TagChip(this.text, this.i, {super.key});
  static const _c = [Color(0xFFF3D9CC), Color(0xFFDDE7D5), Color(0xFFF1E3B8), Color(0xFFD6E1EA), Color(0xFFE6D5E8)];
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: _c[i % _c.length], borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
      );
}

class Card16 extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Card16({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 12, offset: const Offset(0, 4)),
        ]),
        child: child,
      );
}

/// Pestaña activa de la navegación inferior (0 Galería, 1 Asistente, 2 Subir, 3 Perfil).
final tabIndex = ValueNotifier<int>(0);

/// Acción aún no implementada en el prototipo.
void soon(BuildContext c) => ScaffoldMessenger.of(c)
    .showSnackBar(const SnackBar(content: Text('Próximamente')));