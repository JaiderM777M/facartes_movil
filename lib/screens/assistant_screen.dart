import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'detail_screen.dart';

class _Msg {
  final bool user;
  final String text;
  final List<String> artIds;
  _Msg(this.user, this.text, {this.artIds = const []});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;
  final msgs = <_Msg>[
    _Msg(false, '¡Hola! Soy el asistente de FACARTES. Pregúntame por obras de la galería o por técnicas y estilos de arte.'),
  ];

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent + 200,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty || busy) return;
    ctrl.clear();
    setState(() {
      msgs.add(_Msg(true, t));
      busy = true;
    });
    _down();
    try {
      final history = msgs.skip(1).toList(); // sin el saludo inicial
      final recent = history.length > 8 ? history.sublist(history.length - 8) : history;
      final res = await Supabase.instance.client.functions.invoke('assistant-chat', body: {
        'messages': [
          for (final m in recent) {'role': m.user ? 'user' : 'model', 'text': m.text}
        ],
      });
      final d = Map<String, dynamic>.from(res.data as Map);
      msgs.add(_Msg(false, (d['text'] as String?) ?? '...',
          artIds: List<String>.from(d['artwork_ids'] ?? const [])));
    } catch (e) {
      msgs.add(_Msg(false, 'No pude responder ahora. Intenta de nuevo. ($e)'));
    }
    if (mounted) {
      setState(() => busy = false);
      _down();
    }
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final a in artworks.value) a.id: a};
    final maxW = MediaQuery.of(context).size.width * .78;
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(children: [
          Text('Asistente FACARTES', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(width: 8),
          Icon(Icons.auto_awesome, color: kPrimary, size: 20),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: msgs.length + (busy ? 1 : 0),
          itemBuilder: (_, k) {
            final typing = k == msgs.length;
            final m = typing ? null : msgs[k];
            final isUser = m?.user ?? false;
            final arts = (m?.artIds ?? const <String>[]).map((id) => byId[id]).whereType<Artwork>().toList();
            final bubble = Container(
              constraints: BoxConstraints(maxWidth: maxW),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: isUser
                    ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(typing ? 'Pensando...' : m!.text,
                    style: TextStyle(color: isUser ? Colors.white : kInk, height: 1.35)),
                if (arts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: Row(children: [
                      for (final a in arts)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => openDetail(context, a),
                            child: Padding(padding: const EdgeInsets.only(right: 6), child: ArtThumb(a, radius: 12)),
                          ),
                        ),
                    ]),
                  ),
                ],
              ]),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: bubble),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Pregúntale algo al asistente...',
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: busy ? null : _send,
            style: IconButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size(52, 52)),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ]),
      ),
    ]);
  }
}