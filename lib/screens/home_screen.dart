import 'package:flutter/material.dart';
import '../core.dart';
import 'detail_screen.dart';
import '../services/repo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ctrl = TextEditingController();
  String q = '';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  /// Todas las palabras buscadas deben aparecer en alguno de los campos de la obra.
  bool _match(Artwork a) {
    final hay = _norm([a.title, a.artist, a.category, a.technique, a.desc, ...a.tags].join(' '));
    return _norm(q).split(' ').where((w) => w.isNotEmpty).every((w) => hay.contains(w));
  }

  /// Recomienda 3 obras: puntúa por coincidencia de etiquetas y categoría con
  /// las obras que te gustaron o guardaste; desempata por número de likes.
  List<Artwork> _recommend(List<Artwork> list) {
    final prefs = <String, int>{};
    for (final a in list.where((a) => a.liked || a.saved)) {
      for (final t in [...a.tags, a.category]) {
        prefs[_norm(t)] = (prefs[_norm(t)] ?? 0) + 1;
      }
    }
    int score(Artwork a) =>
        [...a.tags, a.category].fold(0, (s, t) => s + (prefs[_norm(t)] ?? 0));

    final pool = list.where((a) => !a.mine && !a.liked && !a.saved).toList();
    final base = pool.isNotEmpty ? pool : list;
    final sorted = [...base]..sort((x, y) {
        final c = score(y).compareTo(score(x));
        return c != 0 ? c : y.likes.compareTo(x.likes);
      });
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Artwork>>(
        valueListenable: artworks,
        builder: (context, list, _) {
          final searching = q.trim().isNotEmpty;
          final shown = searching ? list.where(_match).toList() : list;
          final rec = _recommend(list);
          return RefreshIndicator(
            onRefresh: Repo.refresh,
            color: kPrimary,
            child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.palette, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('FACARTES Móvil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(onPressed: () => soon(context), icon: const Icon(Icons.notifications_none, size: 28)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: TextField(
                    controller: ctrl,
                    onChanged: (v) => setState(() => q = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar obras, artistas, categorías...',
                      prefixIcon: const Icon(Icons.search, color: kMuted),
                      suffixIcon: searching
                          ? IconButton(
                              icon: const Icon(Icons.close, color: kMuted),
                              onPressed: () {
                                ctrl.clear();
                                setState(() => q = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              if (list.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Aún no hay obras.\nSube la primera desde la pestaña Subir.',
                        textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
                  ),
                ),
              if (list.isNotEmpty && !searching) ...[
                const SliverToBoxAdapter(child: _Title('Para ti ✨')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: rec.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, k) => GestureDetector(
                        onTap: () => openDetail(context, rec[k]),
                        child: SizedBox(
                          width: 160,
                          child: Stack(children: [
                            Positioned.fill(child: ArtThumb(rec[k])),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black54],
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(left: 8, top: 8, child: AiBadge(text: 'Según tus gustos')),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Text(rec[k].title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (list.isNotEmpty) SliverToBoxAdapter(child: _Title(searching ? 'Resultados (${shown.length})' : 'Explorar')),
              if (list.isNotEmpty && shown.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('Sin resultados para "$q".', style: const TextStyle(color: kMuted)),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .78),
                  itemCount: shown.length,
                  itemBuilder: (_, k) => GestureDetector(
                    onTap: () => openDetail(context, shown[k]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: SizedBox.expand(child: ArtThumb(shown[k]))),
                      const SizedBox(height: 6),
                      Text(shown[k].title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(shown[k].technique, style: const TextStyle(color: kMuted, fontSize: 12.5)),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      );
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );
}