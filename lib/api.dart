import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

class Link {
  final String name;
  final String url;
  const Link(this.name, this.url);
}

class AppConfig {
  final String name;
  final String stream;
  final String status;
  final String radioPage;
  final String whatsapp;
  final String phone;
  final String hostsImg;
  final String hostsNames;
  final String hostsWhen;
  final bool chatEnabled;
  final bool chatOpen;
  final String chatFrom;
  final String chatTo;
  final List<String> chatSubjects;
  final Map<String, String> social;
  final List<Link> platforms;
  final int minBuild;

  const AppConfig({
    required this.name,
    required this.stream,
    required this.status,
    required this.radioPage,
    required this.whatsapp,
    required this.phone,
    required this.hostsImg,
    required this.hostsNames,
    required this.hostsWhen,
    required this.chatEnabled,
    required this.chatOpen,
    required this.chatFrom,
    required this.chatTo,
    required this.chatSubjects,
    required this.social,
    required this.platforms,
    required this.minBuild,
  });

  /// Used until the site answers (and if it never does): the stream still plays.
  static const fallback = AppConfig(
    name: 'רדיו כחול יוון',
    stream: 'https://icecast.live/listen/livegreece/livegreece',
    status: 'https://icecast.live/listen/livegreece/status-json.xsl',
    radioPage: 'https://leylotyavan.co.il/radio/live-2/',
    whatsapp: '972529964040',
    phone: '052-9964040',
    hostsImg: '',
    hostsNames: 'קרן רחמני ויוני איאטרו',
    hostsWhen: 'בכל שישי מ-12:00',
    chatEnabled: false,
    chatOpen: false,
    chatFrom: '21:00',
    chatTo: '10:00',
    chatSubjects: [],
    social: {},
    platforms: [],
    minBuild: 0,
  );

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final chat = (j['chat'] as Map?)?.cast<String, dynamic>() ?? const {};
    final f = fallback;
    String or(String v, String d) => v.isEmpty ? d : v;
    return AppConfig(
      name: or(_s(j['name']), f.name),
      stream: or(_s(j['stream']), f.stream),
      status: or(_s(j['status']), f.status),
      radioPage: or(_s(j['radioPage']), f.radioPage),
      whatsapp: or(_s(j['whatsapp']), f.whatsapp),
      phone: or(_s(j['phone']), f.phone),
      hostsImg: _s(j['hostsImg']),
      hostsNames: or(_s(j['hostsNames']), f.hostsNames),
      hostsWhen: or(_s(j['hostsWhen']), f.hostsWhen),
      chatEnabled: chat['enabled'] == true,
      chatOpen: chat['open'] == true,
      chatFrom: or(_s(chat['from']), f.chatFrom),
      chatTo: or(_s(chat['to']), f.chatTo),
      chatSubjects: (chat['subjects'] as List?)?.map(_s).toList() ?? const [],
      social: ((j['social'] as Map?) ?? const {}).map((k, v) => MapEntry(_s(k), _s(v))),
      platforms: _list(j['platforms']).map((p) => Link(_s(p['name']), _s(p['url']))).toList(),
      minBuild: _i(j['minBuild']),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String cover;
  final String youtube;

  /// The song's name in Hebrew, when the studio has one ("cc" in the feed).
  final String hebrew;
  final bool isNew;
  final int count;
  final int rank;

  /// When the song was played (recent songs only).
  final DateTime? at;

  const Song({
    required this.title,
    required this.artist,
    this.cover = '',
    this.youtube = '',
    this.hebrew = '',
    this.isNew = false,
    this.count = 0,
    this.rank = 0,
    this.at,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        title: _s(j['title']),
        artist: _s(j['artist']),
        cover: _s(j['cover']),
        youtube: _s(j['youtube']),
        hebrew: j['cc'] is Map ? _s(j['cc']['text']) : '',
        isNew: j['isNew'] == true,
        count: _i(j['count']),
        rank: _i(j['rank']),
        at: _i(j['at']) > 0 ? DateTime.fromMillisecondsSinceEpoch(_i(j['at'])) : null,
      );

  /// "14:05", when the song was played.
  String get airTime => at == null ? '' : '${at!.hour.toString().padLeft(2, '0')}:${at!.minute.toString().padLeft(2, '0')}';
}

/// GET /lym/v1/studio – what the studio computer sent last (every 20 seconds when something changes).
class Studio {
  final Song? now;
  final int started;
  final double duration;
  final List<Song> recent;
  final List<Song> most;
  final List<Song> top;
  final List<Song> fresh;
  final List<Song> next;
  final String program;
  final String showName;
  final String nextName;
  final String nextStart;
  final bool live;

  const Studio({
    this.now,
    this.started = 0,
    this.duration = 0,
    this.recent = const [],
    this.most = const [],
    this.top = const [],
    this.fresh = const [],
    this.next = const [],
    this.program = '',
    this.showName = '',
    this.nextName = '',
    this.nextStart = '',
    this.live = false,
  });

  static const empty = Studio();

  factory Studio.fromJson(Map<String, dynamic> j) {
    final now = (j['now'] as Map?)?.cast<String, dynamic>();
    final show = (j['show'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<Song> songs(String k) => _list(j[k]).map(Song.fromJson).where((s) => s.title.isNotEmpty).toList();
    return Studio(
      now: now != null && _s(now['title']).isNotEmpty ? Song.fromJson(now) : null,
      started: _i(now?['started']),
      duration: _d(now?['duration']),
      recent: songs('recent'),
      most: songs('most'),
      top: songs('top'),
      fresh: songs('new'),
      next: songs('next'),
      program: _s(j['program']),
      showName: _s(show['name']),
      nextName: _s(show['nextName']),
      nextStart: _s(show['nextStart']),
      live: j['fresh'] == true,
    );
  }

  /// No word from the studio in 5 minutes: the song name from Icecast ("Artist - Title").
  Studio withIcecast(String streamTitle) {
    if (streamTitle.isEmpty) return this;
    final parts = streamTitle.split(' - ');
    final song = parts.length >= 2
        ? Song(artist: parts.first.trim(), title: parts.sublist(1).join(' - ').trim())
        : Song(artist: '', title: streamTitle.trim());
    return Studio(
      now: song,
      recent: recent,
      most: most,
      top: top,
      fresh: fresh,
      program: program,
      live: false,
    );
  }

  /// 0..1 of the song on air, or null when the length is unknown.
  double? progress(DateTime at) {
    if (started <= 0 || duration <= 0) return null;
    // The studio reports the start in milliseconds; older feeds sent seconds.
    final start = started > 100000000000 ? started / 1000 : started.toDouble();
    final p = (at.millisecondsSinceEpoch / 1000 - start) / duration;
    return p.clamp(0.0, 1.0);
  }
}

/// "12:00–14:00" inside Hebrew text is shown reversed ("14:00–12:00") unless the range is isolated as LTR.
String ltrTimes(String s) => s.replaceAllMapped(
      RegExp(r'(\d{1,2}:\d{2})\s*[–-]\s*(\d{1,2}:\d{2})'),
      (m) => '\u2066${m[1]}–${m[2]}\u2069',
    );

class Show {
  final int id;
  final String name;
  final int count;
  final String when;
  final int? day;
  final String start;
  final String end;
  final String host;
  final String image;
  final String link;

  const Show({
    required this.id,
    required this.name,
    required this.count,
    required this.when,
    required this.day,
    required this.start,
    required this.end,
    required this.host,
    required this.image,
    required this.link,
  });

  factory Show.fromJson(Map<String, dynamic> j) => Show(
        id: _i(j['id']),
        name: _s(j['name']),
        count: _i(j['count']),
        when: ltrTimes(_s(j['when'])),
        day: j['day'] == null ? null : _i(j['day']),
        start: _s(j['start']),
        end: _s(j['end']),
        host: _s(j['host']),
        image: _s(j['image']),
        link: _s(j['link']),
      );

  String get picture => host.isNotEmpty ? host : image;
}

class Episode {
  final int id;
  final String title;
  final String label;
  final String audio;
  final double duration;
  final List<String> mixcloud;
  final String image;
  final String host;
  final int show;
  final String link;

  const Episode({
    required this.id,
    required this.title,
    required this.label,
    required this.audio,
    required this.duration,
    required this.mixcloud,
    required this.image,
    required this.host,
    required this.show,
    required this.link,
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: _i(j['id']),
        title: _s(j['title']),
        label: _s(j['label']),
        audio: _s(j['audio']),
        duration: _d(j['duration']),
        mixcloud: (j['mixcloud'] as List?)?.map(_s).where((u) => u.isNotEmpty).toList() ?? const [],
        image: _s(j['image']),
        host: _s(j['host']),
        show: _i(j['show']),
        link: _s(j['link']),
      );

  bool get playable => audio.isNotEmpty;
  String get picture => host.isNotEmpty ? host : image;
}

class EpisodePage {
  final List<Episode> episodes;
  final int page;
  final int pages;
  const EpisodePage(this.episodes, this.page, this.pages);
}

class Update {
  final int id;
  final String title;
  final DateTime? date;
  final String excerpt;
  final String image;
  final String link;

  const Update({
    required this.id,
    required this.title,
    required this.date,
    required this.excerpt,
    required this.image,
    required this.link,
  });

  factory Update.fromJson(Map<String, dynamic> j) => Update(
        id: _i(j['id']),
        title: _s(j['title']),
        date: DateTime.tryParse(_s(j['date'])),
        excerpt: _s(j['excerpt']),
        image: _s(j['image']),
        link: _s(j['link']),
      );

  /// A post from the site's own REST API (/wp/v2/posts with _embed).
  factory Update.fromWp(Map<String, dynamic> j) {
    final media = _list((j['_embedded'] as Map?)?['wp:featuredmedia']);
    return Update(
      id: _i(j['id']),
      title: _plain(_s((j['title'] as Map?)?['rendered'])),
      date: DateTime.tryParse(_s(j['date'])),
      excerpt: _plain(_s((j['excerpt'] as Map?)?['rendered'])),
      image: media.isEmpty ? '' : _s(media.first['source_url']),
      link: _s(j['link']),
    );
  }
}

class PostPage {
  final List<Update> posts;
  final int pages;
  const PostPage(this.posts, this.pages);
}

/// Text of a rendered HTML snippet: no tags, entities decoded.
String _plain(String html) {
  const named = {'amp': '&', 'quot': '"', 'apos': "'", 'lt': '<', 'gt': '>', 'nbsp': ' ', 'hellip': '…', 'ndash': '–', 'mdash': '—', 'laquo': '«', 'raquo': '»'};
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-z]+);'), (m) {
        final e = m[1]!;
        if (e.startsWith('#x')) return String.fromCharCode(int.tryParse(e.substring(2), radix: 16) ?? 32);
        if (e.startsWith('#')) return String.fromCharCode(int.tryParse(e.substring(1)) ?? 32);
        return named[e] ?? m[0]!;
      })
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class ChatReply {
  final String reply;
  final List<Link> cards;
  final bool end;
  const ChatReply(this.reply, this.cards, this.end);
}

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

class Api {
  Api({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<dynamic> _get(String route, [Map<String, String> query = const {}]) async {
    final r = await _http.get(apiUri(route, query)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw ApiError('שגיאה ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<Map<String, dynamic>> _post(String route, Map<String, dynamic> body) async {
    final r = await _http
        .post(apiUri(route), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) {
      throw ApiError(j is Map && j['message'] != null ? _s(j['message']) : 'שגיאה ${r.statusCode}');
    }
    return (j as Map).cast<String, dynamic>();
  }

  Future<AppConfig> config() async => AppConfig.fromJson((await _get('/lym/v1/app/config') as Map).cast());

  Future<Studio> studio() async => Studio.fromJson((await _get('/lym/v1/studio') as Map).cast());

  /// The song title that Icecast reports, for when the studio has not reported in a while.
  Future<String> icecastTitle(String statusUrl) async {
    final r = await _http.get(Uri.parse(statusUrl)).timeout(const Duration(seconds: 10));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    var source = (j['icestats'] as Map?)?['source'];
    if (source is List) source = source.isNotEmpty ? source.first : null;
    return source is Map ? _s(source['title']) : '';
  }

  Future<List<Show>> shows() async =>
      _list((await _get('/lym/v1/app/shows') as Map)['shows']).map(Show.fromJson).toList();

  Future<EpisodePage> episodes({int show = 0, int page = 1}) async {
    final j = (await _get('/lym/v1/app/episodes', {'show': '$show', 'page': '$page'}) as Map).cast<String, dynamic>();
    return EpisodePage(_list(j['episodes']).map(Episode.fromJson).toList(), _i(j['page']), _i(j['pages']));
  }

  Future<List<Update>> updates({int page = 1}) async => (await updatesPage(page: page)).posts;

  Future<PostPage> updatesPage({int page = 1}) async {
    final j = await _get('/lym/v1/app/updates', {'page': '$page'}) as Map;
    return PostPage(_list(j['updates']).map(Update.fromJson).toList(), _i(j['pages']));
  }

  /// The magazine (category 4). Sites without /lym/v1/app/magazine yet are read through /wp/v2/posts.
  Future<PostPage> magazine({int page = 1}) async {
    try {
      final j = await _get('/lym/v1/app/magazine', {'page': '$page'}) as Map;
      return PostPage(_list(j['posts'] ?? j['updates']).map(Update.fromJson).toList(), _i(j['pages']));
    } on ApiError {
      final r = await _http
          .get(apiUri('/wp/v2/posts', {'categories': '$kMagazineCat', 'per_page': '20', 'page': '$page', '_embed': 'wp:featuredmedia'}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw ApiError('שגיאה ${r.statusCode}');
      final posts = _list(jsonDecode(utf8.decode(r.bodyBytes))).map(Update.fromWp).toList();
      return PostPage(posts, _i(r.headers['x-wp-totalpages']));
    }
  }

  Future<({int id, String token, String reply})> chatStart(String name, String phone, String subject) async {
    final j = await _post('/lym/v1/chat/start', {'name': name, 'phone': phone, 'subject': subject, 'page': 'app'});
    return (id: _i(j['id']), token: _s(j['token']), reply: _s(j['reply']));
  }

  Future<ChatReply> chatMessage(int id, String token, String text) async {
    final j = await _post('/lym/v1/chat/message', {'id': id, 'token': token, 'text': text});
    final cards = _list(j['cards']).map((c) => Link(_s(c['title']), _s(c['url']))).toList();
    return ChatReply(_s(j['reply']), cards, j['end'] == true);
  }
}
