import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hive_core.dart';
import 'platform_node.dart';
import 'ui/hivenet_ui.dart';

const _port = 8765;
final themeMode = ValueNotifier(ThemeMode.light);
void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder: (_, mode, _) => MaterialApp(
      title: 'HiveNet',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const Dashboard(),
    ),
  );
}

/*
  int tab = 0;
  int get onlineCount => peers.where((p) => p.online).length;
  int get pooledFree => peers.where((p) => p.online).fold(0, (n, p) => n + p.free);

  Widget _page(BuildContext context, String title, List<Widget> children) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...children,
      ]);

  Widget _summary(BuildContext context) => HnCard(child: Wrap(spacing: 20, runSpacing: 16, children: [
    _stat(context, Icons.storage_outlined, size(pooledFree), 'Pooled free'),
    _stat(context, Icons.devices_outlined, '$onlineCount / ${peers.length}', 'Peers online'),
    _stat(context, Icons.photo_library_outlined, '${gallery.length}', 'Distributed images'),
  ]));
  Widget _stat(BuildContext context, IconData icon, String value, String label) => SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(label, style: Theme.of(context).textTheme.labelMedium)]));

  Widget _storagePage(BuildContext c) => _page(c, 'Storage', [_summary(c), const SectionTitle('Node capacity'), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.dns_outlined, color: p.online ? Colors.teal : Theme.of(c).colorScheme.error), title: Text(p.id ?? p.host), subtitle: Text(p.online ? '${size(p.free)} available • ${p.host}:$_port' : '${p.host}:$_port unavailable'), trailing: StatusPill(online: p.online, label: p.online ? 'Live' : 'Offline'))))]);
  Widget _peersPage(BuildContext c) => _page(c, 'Peers', [Text('Live network telemetry • tap a connected peer to browse its files.', style: Theme.of(c).textTheme.bodyMedium), const SizedBox(height: 12), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, onTap: p.online ? () => browsePeer(p) : null, leading: Icon(p.online ? Icons.lan_outlined : Icons.portable_wifi_off_outlined), title: Text(p.id ?? p.host), subtitle: Text('${p.host}:$_port\n${p.online ? '${p.latencyMs ?? '?'} ms • ${(p.reliability * 100).toStringAsFixed(0)}% reliability • ${size(p.free)} free' : 'Offline'}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => peers.remove(p)); await savePeers(); }))))) ]);
  Widget _galleryPage(BuildContext c) => _page(c, 'Gallery', [Text('${gallery.length} images discovered across responsive peers.'), const SizedBox(height: 12), ...gallery.map((g) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, onTap: () => showDistributedImage(g), leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: Theme.of(c).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.image_outlined)), title: Text(g.meta.name), subtitle: Text('${size(g.meta.originalBytes)} → ${size(g.meta.bytes)} • ${g.meta.id.substring(0, 12)}…\n${g.locations.length} replica location(s): ${g.locations.map((p) => p.id ?? p.host).join(', ')}'), isThreeLine: true))))]);
  Widget _routerPage(BuildContext c) { final selected = selectReplicaPeers(peers, (p) => PeerCandidate(key: p.key, freeBytes: p.free, latencyMs: p.latencyMs, online: p.online, successes: p.successes, failures: p.failures), 0); return _page(c, 'Smart Router', [HnCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.account_tree_outlined), const SizedBox(width: 10), const Text('Two independent replicas', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), StatusPill(online: selected.length == 2, label: selected.length == 2 ? 'Ready' : 'Needs peers')]), const SizedBox(height: 12), const Text('Scores use actual free space, probe latency, availability, and verified-transfer reliability.'), ...selected.asMap().entries.map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text('${e.key + 1}')), title: Text(e.value.id ?? e.value.host), subtitle: Text('${size(e.value.free)} free • ${e.value.latencyMs ?? '?'} ms • ${(e.value.reliability * 100).toStringAsFixed(0)}% reliable')))])), const SectionTitle('Eligible peer telemetry'), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: StatusPill(online: p.online, label: p.online ? 'Eligible' : 'Offline'), title: Text(p.id ?? p.host), trailing: Text(p.online ? '${p.latencyMs ?? '?'} ms' : '—'))))]); }
  Widget _activityPage(BuildContext c) => _page(c, 'Activity', [HnCard(child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.verified_outlined), title: Text('Integrity verification'), subtitle: Text('All downloads are SHA-256 verified before preview.'))), const SizedBox(height: 10), HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.sync_outlined), title: const Text('Network diagnostics'), subtitle: Text(status), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: refresh)))]);
  Widget _settingsPage(BuildContext c) => _page(c, 'Settings', [HnCard(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Dark theme'), subtitle: const Text('Premium low-light Material 3 palette'), value: themeMode.value == ThemeMode.dark, onChanged: (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light)), const SizedBox(height: 10), HnCard(child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.repeat_rounded), title: Text('Replication factor'), subtitle: Text('Two verified, distinct Android storage peers are required.'), trailing: Text('2'))), const SizedBox(height: 10), HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.memory_outlined), title: const Text('This device'), subtitle: Text('${PlatformNode.receiverDescription}\n$nodeId'), isThreeLine: true))]);

  @override
  Widget build(BuildContext context) {
    final pages = [_legacyHome(context), _storagePage(context), _peersPage(context), _galleryPage(context), _routerPage(context), _activityPage(context), _settingsPage(context)];
    const labels = ['Home', 'Storage', 'Peers', 'Gallery', 'Router', 'Activity', 'Settings'];
    const icons = [Icons.home_outlined, Icons.storage_outlined, Icons.devices_outlined, Icons.photo_library_outlined, Icons.account_tree_outlined, Icons.bolt_outlined, Icons.settings_outlined];
    return LayoutBuilder(builder: (context, box) { final rail = box.maxWidth >= 760; return Scaffold(appBar: AppBar(title: const Text('HiveNet', style: TextStyle(fontWeight: FontWeight.w800)), actions: [if (busy) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]), floatingActionButton: tab == 0 || tab == 3 ? FloatingActionButton.extended(onPressed: busy ? null : upload, icon: const Icon(Icons.upload_outlined), label: const Text('Upload')) : null, bottomNavigationBar: rail ? null : NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: List.generate(7, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]))), body: Row(children: [if (rail) NavigationRail(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), extended: box.maxWidth > 1050, destinations: List.generate(7, (i) => NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])))), if (rail) const VerticalDivider(width: 1), Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))) ])); });
  }
}
*/

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff5b4bdb),
    brightness: brightness,
    surface: brightness == Brightness.light
        ? const Color(0xfffffbf7)
        : const Color(0xff17151d),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xfff6f3f0)
        : const Color(0xff100f14),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class Peer {
  Peer(this.host);
  final String host;
  String? id;
  int free = 0;
  bool online = false;
  int? latencyMs;
  int successes = 0;
  int failures = 0;
  String get base => 'http://$host:$_port';
  String get key => id ?? host;
  double get reliability => PeerCandidate(
    key: key,
    freeBytes: free,
    latencyMs: latencyMs,
    online: online,
    successes: successes,
    failures: failures,
  ).reliability;

  Map<String, dynamic> toJson() => {
    'host': host,
    'successes': successes,
    'failures': failures,
  };
}

class Meta {
  Meta(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String? ?? 'image.jpg',
      bytes = (j['bytes'] as num).toInt(),
      originalBytes =
          (j['originalBytes'] as num?)?.toInt() ?? (j['bytes'] as num).toInt();
  final String id, name;
  final int bytes;
  final int originalBytes;
  double get compressionRatio => originalBytes == 0 ? 1 : bytes / originalBytes;
}

class GalleryImage {
  GalleryImage(this.meta);
  final Meta meta;
  final List<Peer> locations = [];
}

class ActivityEvent {
  ActivityEvent(this.title, this.detail, this.icon, {this.error = false})
    : time = DateTime.now();
  final String title, detail;
  final IconData icon;
  final DateTime time;
  final bool error;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final picker = ImagePicker();
  final peers = <Peer>[];
  Box<dynamic>? _webImages;
  var images = <Meta>[];
  var gallery = <GalleryImage>[];
  String? lastCompression;
  final activity = <ActivityEvent>[];
  int tab = 0;
  var nodeId = '';
  var busy = true;
  var status = 'Starting node...';
  void log(String title, String detail, IconData icon, {bool error = false}) {
    activity.insert(0, ActivityEvent(title, detail, icon, error: error));
    if (activity.length > 30) activity.removeLast();
  }

  @override
  void initState() {
    super.initState();
    init().catchError((Object error, StackTrace stack) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Node startup failed: $error';
        });
      }
    });
  }

  String randomId() => base64Url
      .encode(List.generate(12, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      _webImages = await Hive.openBox<dynamic>('hivenet_images');
    }
    final prefs = await SharedPreferences.getInstance();
    nodeId = prefs.getString('node') ?? randomId();
    await prefs.setString('node', nodeId);
    for (final saved
        in (jsonDecode(prefs.getString('peers') ?? '[]') as List)) {
      // Accept the old string-only peer list while retaining real transfer
      // history for the smart router in the new format.
      final data = saved is String
          ? <String, dynamic>{'host': saved}
          : Map<String, dynamic>.from(saved as Map);
      final peer = Peer(data['host'] as String)
        ..successes = (data['successes'] as num?)?.toInt() ?? 0
        ..failures = (data['failures'] as num?)?.toInt() ?? 0;
      peers.add(peer);
    }
    // A foreground receiver is native because a Flutter activity may be
    // paused or destroyed while another LAN node uploads a replica.
    await PlatformNode.start(nodeId);
    await refresh();
  }

  Future<void> savePeers() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'peers',
      jsonEncode(peers.map((e) => e.toJson()).toList()),
    );
  }

  Future<http.Response> get(String u) =>
      http.get(Uri.parse(u)).timeout(const Duration(seconds: 5));

  Future<void> refresh() async {
    if (nodeId.isEmpty) return;
    if (mounted) {
      setState(() {
        busy = true;
        status = 'Checking peers...';
      });
    }
    await Future.wait(
      peers.map((p) async {
        try {
          final clock = Stopwatch()..start();
          final r = await get('${p.base}/v1/info');
          clock.stop();
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body) as Map<String, dynamic>;
            p.online = true;
            p.id = j['nodeId'] as String?;
            p.free = (j['freeBytes'] as num?)?.toInt() ?? 0;
            p.latencyMs = clock.elapsedMilliseconds;
          } else {
            p.online = false;
            p.latencyMs = null;
          }
        } catch (_) {
          p.online = false;
          p.latencyMs = null;
        }
      }),
    );
    final own = <Meta>[];
    if (kIsWeb) {
      images = _webImages!.values
          .map((e) => Meta(Map<String, dynamic>.from(e['meta'] as Map)))
          .toList();
      own.addAll(images);
    } else {
      try {
        final r = await get('http://127.0.0.1:$_port/v1/files');
        if (r.statusCode == 200) {
          images = (jsonDecode(r.body) as List)
              .map((e) => Meta(e as Map<String, dynamic>))
              .toList();
          own.addAll(images);
        }
      } catch (_) {}
    }
    await _refreshGallery(own);
    log(
      'Network scan complete',
      '${peers.where((p) => p.online).length} peers online',
      Icons.radar,
    );
    if (mounted) {
      setState(() {
        busy = false;
        status = kIsWeb
            ? 'Browser client connected to LAN peers'
            : 'Node active on port $_port';
      });
    }
  }

  Future<void> _refreshGallery(List<Meta> own) async {
    final entries = <String, GalleryImage>{};
    void add(Meta meta, [Peer? location]) {
      final entry = entries.putIfAbsent(meta.id, () => GalleryImage(meta));
      if (location != null &&
          !entry.locations.any((p) => p.key == location.key)) {
        entry.locations.add(location);
      }
    }

    for (final meta in own) {
      add(meta);
    }
    await Future.wait(
      peers.where((p) => p.online).map((peer) async {
        try {
          final response = await get('${peer.base}/v1/files');
          if (response.statusCode != 200) return;
          for (final raw in jsonDecode(response.body) as List) {
            add(Meta(raw as Map<String, dynamic>), peer);
          }
        } catch (_) {
          // A failed scan is not proof that an earlier replica has vanished.
        }
      }),
    );
    gallery = entries.values.toList()
      ..sort((a, b) => a.meta.name.compareTo(b.meta.name));
  }

  Future<void> addPeer() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add LAN peer'),
        content: TextField(
          controller: text,
          decoration: const InputDecoration(hintText: '192.168.1.42'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, text.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final host = value
        ?.replaceFirst(RegExp(r'^https?://'), '')
        .split(':')
        .first
        .trim();
    if (host != null && host.isNotEmpty && !peers.any((p) => p.host == host)) {
      setState(() => peers.add(Peer(host)));
      log('Peer added', '$host:$_port', Icons.add_link);
      await savePeers();
      await refresh();
    }
  }

  Future<bool> send(
    Peer peer,
    String id,
    String name,
    CompressedImage image,
  ) async {
    try {
      final r = await http
          .put(
            Uri.parse('${peer.base}/v1/files/$id'),
            body: image.bytes,
            headers: {
              'Content-Type': 'image/jpeg',
              'x-hivenet-sha256': id,
              'x-hivenet-name': Uri.encodeComponent(name),
              'x-hivenet-mime': 'image/jpeg',
              'x-hivenet-original-bytes': '${image.originalBytes}',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 201) return false;
      final ack = jsonDecode(r.body) as Map<String, dynamic>;
      return ack['stored'] == true && ack['sha256'] == id;
    } catch (_) {
      return false;
    }
  }

  Future<void> upload() async {
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    setState(() {
      busy = true;
      status = 'Compressing image...';
    });
    try {
      final prepared = compressImage(await selected.readAsBytes());
      final id = prepared.id;
      lastCompression =
          '${size(prepared.originalBytes)} → ${size(prepared.bytes.length)} '
          '(${((1 - prepared.ratio) * 100).toStringAsFixed(0)}% smaller, '
          '${prepared.width}×${prepared.height})';
      PeerCandidate candidate(Peer peer) => PeerCandidate(
        key: peer.key,
        freeBytes: peer.free,
        latencyMs: peer.latencyMs,
        online: peer.online,
        successes: peer.successes,
        failures: peer.failures,
      );
      // Router only considers responsive peers with enough real free space.
      if (selectReplicaPeers(peers, candidate, prepared.bytes.length).length !=
          2) {
        throw Exception('Exactly two distinct eligible peers are required.');
      }
      setState(() => status = 'Replicating to two storage nodes...');
      // A failed top-ranked device is replaced by the next ranked *distinct*
      // peer; a successful transfer is never faked or counted twice.
      final attemptedKeys = <String>{};
      final replicas = <Peer>[];
      while (replicas.length < 2) {
        final next = selectReplicaPeers(
          peers.where((peer) => !attemptedKeys.contains(peer.key)),
          candidate,
          prepared.bytes.length,
        );
        if (next.isEmpty) break;
        final peer = next.first;
        attemptedKeys.add(peer.key);
        if (await send(peer, id, selected.name, prepared)) {
          peer.successes++;
          replicas.add(peer);
        } else {
          peer.failures++;
        }
      }
      await savePeers();
      if (replicas.length != 2) {
        log(
          'Replication failed',
          'Two verified replicas were not available.',
          Icons.error_outline,
          error: true,
        );
        throw Exception('Could not verify two independent replica writes.');
      }
      if (kIsWeb) {
        await _webImages!.put(id, {
          'meta': {
            'id': id,
            'name': selected.name,
            'bytes': prepared.bytes.length,
            'originalBytes': prepared.originalBytes,
          },
          'bytes': prepared.bytes,
        });
      }
      if (mounted) {
        log(
          'Image replicated',
          '${replicas.map((p) => p.id ?? p.host).join(' and ')} verified $id',
          Icons.verified,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Replicated and verified on both storage nodes.'),
          ),
        );
      }
    } catch (e) {
      log('Upload failed', '$e', Icons.error_outline, error: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
    await refresh();
  }

  Future<void> showImage(Meta m, [Peer? peer]) async {
    try {
      if (kIsWeb && peer == null) {
        final record = _webImages!.get(m.id) as Map;
        final bytes = Uint8List.fromList(
          List<int>.from(record['bytes'] as List),
        );
        if (mounted) await _showImage(m.name, _verifiedBytes(m.id, bytes));
        return;
      }
      final r = await get(
        '${peer?.base ?? 'http://127.0.0.1:$_port'}/v1/files/${m.id}',
      );
      if (r.statusCode != 200) throw Exception();
      if (mounted) await _showImage(m.name, _verifiedBytes(m.id, r.bodyBytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not retrieve image.')),
        );
      }
    }
  }

  /// Attempts every known replica in order. A missing/offline first device is
  /// therefore recoverable as long as its other replica is available.
  Future<void> showDistributedImage(GalleryImage image) async {
    if (kIsWeb && _webImages!.containsKey(image.meta.id)) {
      await showImage(image.meta);
      return;
    }
    if (!kIsWeb && images.any((meta) => meta.id == image.meta.id)) {
      await showImage(image.meta);
      return;
    }
    for (final peer in image.locations.where((peer) => peer.online)) {
      try {
        final response = await get('${peer.base}/v1/files/${image.meta.id}');
        if (response.statusCode != 200) continue;
        if (mounted) {
          await _showImage(
            image.meta.name,
            _verifiedBytes(image.meta.id, response.bodyBytes),
          );
        }
        return;
      } catch (_) {
        // Try the next independently stored replica.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available verified replica for this image.'),
        ),
      );
    }
  }

  /// A retrieval is only displayed when it still matches its content address.
  /// Android verifies on receipt too; this catches corruption in transit or at
  /// rest before a peer's image is rendered on either platform.
  Uint8List _verifiedBytes(String id, List<int> bytes) {
    final imageBytes = Uint8List.fromList(bytes);
    if (!matchesContentId(id, imageBytes)) {
      throw const FormatException('Image checksum did not match its ID.');
    }
    return imageBytes;
  }

  Future<void> _showImage(String name, Uint8List bytes) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
      ),
    ),
  );

  Future<void> browsePeer(Peer peer) async {
    try {
      final r = await get('${peer.base}/v1/files');
      if (r.statusCode != 200) throw Exception();
      final files = (jsonDecode(r.body) as List)
          .map((e) => Meta(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => ListView(
          children: [
            ListTile(
              title: Text('${peer.id ?? peer.host} gallery'),
              subtitle: Text('${files.length} stored images'),
            ),
            ...files.map(
              (m) => ListTile(
                leading: const Icon(Icons.image),
                title: Text(m.name),
                subtitle: Text(size(m.bytes)),
                onTap: () {
                  Navigator.pop(c);
                  showImage(m, peer);
                },
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load peer gallery.')),
        );
      }
    }
  }

  String size(int n) => n > 1048576
      ? '${(n / 1048576).toStringAsFixed(1)} MB'
      : '${(n / 1024).toStringAsFixed(0)} KB';
  Widget _home(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('HiveNet'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(onPressed: addPeer, icon: const Icon(Icons.add_link)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : upload,
      icon: const Icon(Icons.upload),
      label: const Text('Upload image'),
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HnCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THIS DEVICE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(nodeId),
                  Text(status),
                  Text(PlatformNode.receiverDescription),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Peers (${peers.where((p) => p.online).length}/${peers.length} online)',
            style: Theme.of(c).textTheme.titleLarge,
          ),
          ...peers.map(
            (p) => HnCard(
              child: ListTile(
                leading: Icon(
                  p.online ? Icons.check_circle : Icons.cloud_off,
                  color: p.online ? Colors.green : Colors.red,
                ),
                title: Text(p.id ?? p.host),
                subtitle: Text(
                  '${p.host}:$_port${p.online ? ' - ${size(p.free)} free, ${p.latencyMs ?? '?'} ms, ${(p.reliability * 100).toStringAsFixed(0)}% reliable' : ' - offline'}',
                ),
                onTap: p.online ? () => browsePeer(p) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => peers.remove(p));
                    await savePeers();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Distributed gallery (${gallery.length})',
            style: Theme.of(c).textTheme.titleLarge,
          ),
          ...gallery.map(
            (entry) => HnCard(
              child: ListTile(
                leading: const Icon(Icons.hub),
                title: Text(entry.meta.name),
                subtitle: Text(
                  '${size(entry.meta.originalBytes)} → ${size(entry.meta.bytes)} '
                  '(${((1 - entry.meta.compressionRatio) * 100).toStringAsFixed(0)}% smaller)\n'
                  '${entry.meta.id.substring(0, 12)}… • ${entry.locations.length} peer replica(s): '
                  '${entry.locations.map((p) => p.id ?? p.host).join(', ')}',
                ),
                isThreeLine: true,
                onTap: () => showDistributedImage(entry),
              ),
            ),
          ),
          if (lastCompression != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Last upload: $lastCompression'),
            ),
          const SizedBox(height: 12),
          Text(
            'Local gallery (${images.length})',
            style: Theme.of(c).textTheme.titleLarge,
          ),
          ...images.map(
            (m) => HnCard(
              child: ListTile(
                leading: const Icon(Icons.image),
                title: Text(m.name),
                subtitle: Text(
                  '${size(m.bytes)} - ${m.id.substring(0, 10)}...',
                ),
                onTap: () => showImage(m),
              ),
            ),
          ),
          if (images.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No local replicas yet. This device becomes a replica when another device uploads.',
              ),
            ),
        ],
      ),
    ),
  );

  int _tab = 0;
  Widget _simplePage(BuildContext c, String title, List<Widget> content) =>
      ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: Theme.of(c).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...content,
        ],
      );
  Widget _storage(BuildContext c) => _simplePage(c, 'Storage', [
    HnCard(
      child: Text(
        '${size(peers.where((p) => p.online).fold(0, (n, p) => n + p.free))} pooled live capacity',
        style: Theme.of(c).textTheme.titleLarge,
      ),
    ),
    const SizedBox(height: 16),
    ...peers.map(
      (p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: HnCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.storage_outlined,
              color: p.online ? Colors.teal : Theme.of(c).colorScheme.error,
            ),
            title: Text(p.id ?? p.host),
            subtitle: Text(p.online ? '${size(p.free)} available' : 'Offline'),
            trailing: StatusPill(
              online: p.online,
              label: p.online ? 'Live' : 'Offline',
            ),
          ),
        ),
      ),
    ),
  ]);
  Widget _peers(BuildContext c) => _simplePage(c, 'Peers', [
    ...peers.map(
      (p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: HnCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: p.online ? () => browsePeer(p) : null,
            leading: const Icon(Icons.devices_outlined),
            title: Text(p.id ?? p.host),
            subtitle: Text(
              '${p.host}:$_port • ${p.online ? '${p.latencyMs ?? '?'} ms • ${(p.reliability * 100).toStringAsFixed(0)}% reliable' : 'Offline'}',
            ),
          ),
        ),
      ),
    ),
  ]);
  Widget _gallery(BuildContext c) => _simplePage(c, 'Gallery', [
    ...gallery.map(
      (g) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: HnCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => showDistributedImage(g),
            leading: const Icon(Icons.image_outlined),
            title: Text(g.meta.name),
            subtitle: Text(
              '${size(g.meta.bytes)} • ${g.meta.id.substring(0, 12)}… • ${g.locations.length} replica locations',
            ),
          ),
        ),
      ),
    ),
  ]);
  Widget _router(BuildContext c) => _simplePage(c, 'Smart Router', [
    HnCard(
      child: const Text(
        'The router requires two distinct online Android peers and ranks them using live free capacity, measured latency, and verified transfer reliability.',
      ),
    ),
    const SizedBox(height: 16),
    ...peers.map(
      (p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: HnCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: StatusPill(
              online: p.online,
              label: p.online ? 'Eligible' : 'Offline',
            ),
            title: Text(p.id ?? p.host),
            subtitle: Text(
              '${size(p.free)} free • ${p.latencyMs ?? '?'} ms • ${(p.reliability * 100).toStringAsFixed(0)}% reliability',
            ),
          ),
        ),
      ),
    ),
  ]);
  Widget _settings(BuildContext c) => _simplePage(c, 'Settings', [
    HnCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Dark theme'),
        subtitle: const Text('Use HiveNet’s Material 3 dark palette.'),
        value: themeMode.value == ThemeMode.dark,
        onChanged: (v) =>
            themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
    const SizedBox(height: 10),
    HnCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.network_check_outlined),
        title: const Text('Run diagnostics'),
        subtitle: Text(status),
        onTap: refresh,
      ),
    ),
    const SizedBox(height: 10),
    const HnCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.repeat_rounded),
        title: Text('Replication factor'),
        subtitle: Text('Two independent verified replicas'),
        trailing: Text('2'),
      ),
    ),
  ]);
  @override
  Widget build(BuildContext c) {
    final pages = [
      _home(c),
      _storage(c),
      _peers(c),
      _gallery(c),
      _router(c),
      _settings(c),
    ];
    const labels = [
      'Home',
      'Storage',
      'Peers',
      'Gallery',
      'Router',
      'Settings',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.storage_outlined,
      Icons.devices_outlined,
      Icons.photo_library_outlined,
      Icons.account_tree_outlined,
      Icons.settings_outlined,
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: List.generate(
          6,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}
