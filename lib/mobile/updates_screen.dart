import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// "עדכונים": the site's latest updates (news, weather, events in Greece).
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  Future<List<Update>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= Scope.of(context).state.api.updates();
  }

  Future<void> _reload() async {
    final f = Scope.of(context).state.api.updates();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Update>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: const [
              Padding(padding: EdgeInsets.all(32), child: Text('אין עדכונים כרגע.', textAlign: TextAlign.center, style: TextStyle(color: Ly.muted))),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final u = items[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openUrl(u.link),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (u.image.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: LayoutBuilder(builder: (c, b) => Artwork(url: u.image, size: b.maxWidth, radius: 0))),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtDate(u.date), style: const TextStyle(color: Ly.sky, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(u.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
                        if (u.excerpt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(u.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D2E8), height: 1.4)),
                        ],
                      ]),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
