import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core.dart';
import 'detail_screen.dart';
import '../services/repo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int tab = 0;
  bool uploading = false;

  Future<void> _changePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 600, imageQuality: 85);
      if (x == null) return;
      if (mounted) setState(() => uploading = true);
      final bytes = await x.readAsBytes();
      await Repo.updateAvatar(bytes, x.mimeType ?? 'image/jpeg');
      m.showSnackBar(const SnackBar(content: Text('Foto de perfil actualizada')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('No se pudo actualizar la foto: $e')));
    }
    if (mounted) setState(() => uploading = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Artwork>>(
        valueListenable: artworks,
        builder: (context, list, _) {
          final mine = list.where((a) => a.mine).toList();
          final shown = tab == 0 ? mine : list.where((a) => a.saved).toList();
          final likes = mine.fold<int>(0, (s, a) => s + a.likes);
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Column(children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(onPressed: Repo.signOut, tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout)),
                ),
                GestureDetector(
                  onTap: uploading ? null : _changePhoto,
                  child: Stack(children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: Repo.avatar,
                      builder: (_, url, __) => UserAvatar(url, radius: 52),
                    ),
                    if (uploading)
                      const Positioned.fill(child: Center(child: CircularProgressIndicator(color: kPrimary))),
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: kPrimary,
                        child: Icon(Icons.photo_camera, size: 16, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(Repo.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('Artes Visuales', style: TextStyle(color: kMuted)),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _stat('${mine.length}', 'Obras subidas'),
                    const VerticalDivider(width: 40, thickness: 1),
                    _stat('$likes', 'Me gusta recibidos'),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  for (final e in ['Mis obras', 'Guardadas'].asMap().entries)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => tab = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: tab == e.key ? kPrimary : Colors.black12, width: 2.5))),
                          child: Text(e.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700, color: tab == e.key ? kPrimary : kMuted)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
              ]),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: shown.length,
                itemBuilder: (_, k) =>
                    GestureDetector(onTap: () => openDetail(context, shown[k]), child: ArtThumb(shown[k], radius: 12)),
              ),
            ),
          ]);
        },
      );

  Widget _stat(String n, String l) => Column(children: [
        Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: kMuted, fontSize: 12.5)),
      ]);
}