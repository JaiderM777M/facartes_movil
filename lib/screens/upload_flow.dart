import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core.dart';
import '../services/ai_service.dart';
import '../services/repo.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  Future<void> _pick(BuildContext context, ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyzingScreen(bytes: bytes, mime: x.mimeType ?? 'image/jpeg')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir la imagen: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget opt(IconData i, String t, VoidCallback f) => GestureDetector(
          onTap: f,
          child: Card16(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(children: [
              CircleAvatar(radius: 30, backgroundColor: kPrimary.withOpacity(.12), child: Icon(i, size: 30, color: kPrimary)),
              const SizedBox(height: 12),
              Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => tabIndex.value = 0),
        title: const Text('Subir obra'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          opt(Icons.photo_camera_outlined, 'Tomar foto', () => _pick(context, ImageSource.camera)),
          const SizedBox(height: 16),
          opt(Icons.image_outlined, 'Elegir de la galería', () => _pick(context, ImageSource.gallery)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Icon(Icons.auto_awesome, size: 16, color: kPrimary),
            SizedBox(width: 6),
            Flexible(
              child: Text('La IA analizará tu obra automáticamente para sugerirte etiquetas y descripción',
                  textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 13)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class AnalyzingScreen extends StatefulWidget {
  final Uint8List bytes;
  final String mime;
  const AnalyzingScreen({super.key, required this.bytes, required this.mime});
  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  AiResult? res;
  String? error;
  int shown = 0;
  Timer? t;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final r = await AiService.analyze(widget.bytes, widget.mime);
      if (!mounted) return;
      setState(() => res = r);
      t = Timer.periodic(const Duration(milliseconds: 400), (x) {
        if (!mounted || shown >= r.tags.length) { x.cancel(); return; }
        setState(() => shown++);
      });
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo analizar la imagen. Puedes continuar manualmente.');
    }
  }

  @override
  void dispose() { t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r = res;
    final ready = r != null || error != null;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Analizando obra')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(widget.bytes, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        const SizedBox(height: 16),
        Card16(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: kPrimary),
              const SizedBox(width: 8),
              Text(error != null ? 'No se pudo analizar' : r == null ? 'Analizando con IA...' : 'Análisis completo',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: ready ? 1 : null, minHeight: 6, color: kPrimary, backgroundColor: kPrimary.withOpacity(.12)),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: kMuted))),
          ]),
        ),
        if (r != null) ...[
          const SizedBox(height: 20),
          const Text('Etiquetas sugeridas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var k = 0; k < r.tags.length; k++)
              AnimatedOpacity(opacity: k < shown ? 1 : 0, duration: const Duration(milliseconds: 400), child: TagChip(r.tags[k], k)),
          ]),
          const SizedBox(height: 20),
          Card16(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Descripción generada por IA', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(r.description, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 10),
              const AiBadge(),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: ready
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublishScreen(bytes: widget.bytes, mime: widget.mime, ai: r ?? AiResult.empty)))
              : null,
          child: const Text('Continuar'),
        ),
      ]),
    );
  }
}

class PublishScreen extends StatefulWidget {
  final Uint8List bytes;
  final String mime;
  final AiResult ai;
  const PublishScreen({super.key, required this.bytes, required this.mime, required this.ai});
  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  static const _cats = ['Pintura', 'Escultura', 'Arte digital', 'Dibujo', 'Fotografía', 'Otro'];
  final title = TextEditingController(), tech = TextEditingController(), dims = TextEditingController(), year = TextEditingController();
  late final desc = TextEditingController(text: widget.ai.description);
  late String cat = _cats.contains(widget.ai.category) ? widget.ai.category : 'Otro';
  String? err;
  bool busy = false;

  Widget label(String t, {bool ai = false}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Row(children: [
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (ai) const AiBadge(text: 'IA'),
        ]),
      );

  Future<void> publish() async {
    if (title.text.trim().isEmpty) {
      setState(() => err = 'Escribe un título para tu obra');
      return;
    }
    setState(() { busy = true; err = null; });
    final nav = Navigator.of(context);
    final m = ScaffoldMessenger.of(context);
    try {
      await Repo.publish(
        bytes: widget.bytes, mime: widget.mime, title: title.text.trim(), desc: desc.text.trim(),
        category: cat, technique: tech.text.trim(), year: year.text.trim(), dims: dims.text.trim(),
        tags: widget.ai.tags,
      );
      nav.popUntil((r) => r.isFirst);
      tabIndex.value = 0;
      m.showSnackBar(const SnackBar(content: Text('¡Obra publicada!')));
    } catch (e) {
      if (mounted) setState(() => busy = false);
      m.showSnackBar(SnackBar(content: Text('No se pudo publicar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Confirmar y publicar')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          SizedBox(
            height: 140,
            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(widget.bytes, fit: BoxFit.cover, width: double.infinity)),
          ),
          label('Título'),
          TextField(controller: title, decoration: InputDecoration(hintText: 'Escribe un título para tu obra', errorText: err)),
          label('Descripción', ai: true),
          TextField(controller: desc, maxLines: 4),
          label('Categoría', ai: true),
          DropdownButtonFormField<String>(
            value: cat,
            decoration: const InputDecoration(),
            items: _cats.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => cat = v!),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Detalles de la obra (ingresa tú)', style: TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
          label('Técnica'),
          TextField(controller: tech, decoration: const InputDecoration(hintText: 'Ej: Óleo sobre lienzo')),
          label('Dimensiones'),
          TextField(controller: dims, decoration: const InputDecoration(hintText: 'Ej: 80 x 60 cm')),
          label('Año de creación'),
          TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Ej: 2025')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : publish,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Publicar'),
          ),
        ]),
      );
}
