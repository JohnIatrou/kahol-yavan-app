import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

/// "עוד": contact, notifications, the site and social networks.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = Scope.of(context);
    final c = scope.state.config;
    final push = scope.push;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(
        title: 'דברו איתנו',
        mark: Ly.wa,
        child: Column(children: [
          _Row(
            icon: Icons.chat,
            color: Ly.wa,
            title: 'וואטסאפ לאולפן',
            subtitle: 'בקשות לשירים, ברכות והזמנות',
            onTap: () => openUrl(whatsappUrl(c.whatsapp, 'שלום מאפליקציית רדיו כחול יוון')),
          ),
          if (c.chatEnabled)
            _Row(
              icon: Icons.support_agent,
              color: Ly.sky,
              title: 'צ\'אט עם העוזר של לילות יוון',
              subtitle: 'בשעות ${c.chatFrom}–${c.chatTo}',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen())),
            ),
          _Row(icon: Icons.phone, color: Ly.sky, title: c.phone, subtitle: 'טלפון', onTap: () => openUrl('tel:${c.phone}')),
        ]),
      ),
      ListenableBuilder(
        listenable: push,
        builder: (context, _) => Panel(
          title: 'התראות',
          mark: Ly.fresh,
          child: Column(children: [
            for (final t in PushTopic.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: push.enabled[t]!,
                onChanged: (v) => push.set(t, v),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.subtitle, style: const TextStyle(color: Ly.muted)),
              ),
          ]),
        ),
      ),
      Panel(
        title: 'לילות יוון',
        mark: Ly.aegean,
        child: Column(children: [
          _Row(icon: Icons.public, color: Ly.sky, title: 'האתר', subtitle: 'הופעות, טברנות, טיולים והזמנות', onTap: () => openUrl(kBaseUrl)),
          _Row(icon: Icons.radio, color: Ly.sky, title: 'עמוד הרדיו באתר', subtitle: '', onTap: () => openUrl(c.radioPage)),
          if (c.social.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in c.social.entries)
                  ActionChip(label: Text(_socialName(e.key)), onPressed: () => openUrl(e.value), backgroundColor: Ly.card),
              ]),
            ),
          _Row(
            icon: Icons.share,
            color: Ly.sky,
            title: 'שתפו את האפליקציה',
            subtitle: '',
            onTap: () => SharePlus.instance.share(ShareParams(text: 'רדיו כחול יוון – מוזיקה יוונית 24 שעות:\n$kPlayStoreUrl\n$kAppStoreUrl')),
          ),
        ]),
      ),
      const Center(child: Text('רדיו כחול יוון · לילות יוון', style: TextStyle(color: Ly.muted, fontSize: 12))),
    ]);
  }

  static String _socialName(String k) =>
      const {'facebook': 'פייסבוק', 'instagram': 'אינסטגרם', 'youtube': 'יוטיוב', 'twitter': 'X (טוויטר)'}[k] ?? k;
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(color: Ly.muted)),
        trailing: const Icon(Icons.chevron_left, color: Ly.muted),
        onTap: onTap,
      );
}
