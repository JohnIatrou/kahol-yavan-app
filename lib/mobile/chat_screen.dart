import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The site's night chat (21:00–10:00): name, mobile and subject first, then the conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Msg {
  final bool mine;
  final String text;
  final List<Link> cards;
  _Msg(this.mine, this.text, [this.cards = const []]);
}

class _ChatScreenState extends State<ChatScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String? _subject;
  int? _id;
  String _token = '';
  bool _busy = false;
  bool _ended = false;
  String? _error;
  final _msgs = <_Msg>[];

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Scope.of(context).state.api.chatStart(_name.text.trim(), _phone.text.trim(), _subject ?? '');
      setState(() {
        _id = r.id;
        _token = r.token;
        _msgs.add(_Msg(false, r.reply));
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_Msg(true, t));
      _text.clear();
      _busy = true;
    });
    _toEnd();
    try {
      final r = await Scope.of(context).state.api.chatMessage(_id!, _token, t);
      setState(() {
        _msgs.add(_Msg(false, r.reply, r.cards));
        _ended = r.end;
      });
    } catch (e) {
      setState(() => _msgs.add(_Msg(false, e.toString())));
    } finally {
      setState(() => _busy = false);
      _toEnd();
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    final c = Scope.of(context).state.config;
    return Scaffold(
      appBar: AppBar(title: const Text('צ\'אט עם העוזר של לילות יוון')),
      body: _id == null ? _form(c) : _conversation(c),
    );
  }

  Widget _form(AppConfig c) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('בשעות ${c.chatFrom}–${c.chatTo} העוזר עונה מתוך האתר, עם קישורים להזמנה. נציג יחזור אליכם בבוקר.',
          style: const TextStyle(color: Ly.muted, height: 1.4)),
      const SizedBox(height: 20),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'שם מלא', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'נייד', hintText: '052-1234567', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _subject,
        decoration: const InputDecoration(labelText: 'נושא', border: OutlineInputBorder()),
        items: c.chatSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => _subject = v),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Ly.live))),
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _start, child: Text(_busy ? 'רגע…' : 'התחלת שיחה')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => openUrl(whatsappUrl(c.whatsapp)),
        icon: const Icon(Icons.chat, color: Ly.wa),
        label: const Text('או בוואטסאפ'),
      ),
    ]);
  }

  Widget _conversation(AppConfig c) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount: _msgs.length + (_busy ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == _msgs.length) {
              return const Align(alignment: AlignmentDirectional.centerStart, child: Padding(padding: EdgeInsets.all(12), child: Text('…', style: TextStyle(fontSize: 24))));
            }
            final m = _msgs[i];
            return Align(
              alignment: m.mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: m.mine ? Ly.aegean : Ly.card, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.text, style: const TextStyle(height: 1.4)),
                  ...m.cards.map((l) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton(onPressed: () => openUrl(l.url), child: Text(l.name, maxLines: 2)),
                      )),
                ]),
              ),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _ended
              ? FilledButton.icon(
                  onPressed: () => openUrl(whatsappUrl(c.whatsapp)),
                  style: FilledButton.styleFrom(backgroundColor: Ly.wa),
                  icon: const Icon(Icons.chat),
                  label: const Text('להמשך בוואטסאפ'),
                )
              : Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 600,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'מה מחפשים?', counterText: '', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
                ]),
        ),
      ),
    ]);
  }
}
