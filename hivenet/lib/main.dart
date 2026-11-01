// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hive_core.dart';
import 'platform_node.dart';
import 'secure_file.dart';
import 'ui/hivenet_ui.dart';

const _port = 8765;
final themeMode = ValueNotifier(ThemeMode.dark);
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

  Widget _storagePage(BuildContext c) => _page(c, 'Storage', [_summary(c), const SectionTitle('Node capacity'), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.dns_outlined, color: p.online ? Colors.teal : Theme.of(c).colorScheme.error), title: Text(p.id ?? p.host), subtitle: Text(p.online ? '${size(p.free)} available • ${p.host}:$_port' : '${p.host}:$_port unavailable'), trailing: StatusPill(online: p.online, label: p.online ? 'Live' : 'Offline'))))])];
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

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kCyan,
    brightness: brightness,
    primary: kCyan,
    secondary: kPurple,
    tertiary: kAmber,
    surface: dark ? kDarkSurface : const Color(0xffF5F7F6),
    error: kRed,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : const Color(0xffEEF2F0),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff14222B) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kCyan.withOpacity(0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: dark ? Colors.white : const Color(0xff1E1B4B),
      displayColor: dark ? Colors.white : const Color(0xff1D3037),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain models (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard widget
// ─────────────────────────────────────────────────────────────────────────────
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  final picker = ImagePicker();
  final vault = OwnerVault();
  final ownerRecords = <String, Map<String, dynamic>>{};
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

  // Background gradient animation controller
  late final AnimationController _bgAnimationController;
  // Storage ring animation controller
  late final AnimationController _storageRingCtrl;
  // Router topology animation controller
  late final AnimationController _routerAnimCtrl;

  void log(String title, String detail, IconData icon, {bool error = false}) {
    activity.insert(0, ActivityEvent(title, detail, icon, error: error));
    if (activity.length > 30) activity.removeLast();
  }

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _storageRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _routerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    init().catchError((Object error, StackTrace stack) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Node startup failed: $error';
        });
      }
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _storageRingCtrl.dispose();
    _routerAnimCtrl.dispose();
    super.dispose();
  }

  // ─── business logic (all unchanged) ───────────────────────────────────────

  String randomId() => base64Url
      .encode(List.generate(12, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');

  Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      _webImages = await Hive.openBox<dynamic>('hivenet_images');
    }
    final prefs = await SharedPreferences.getInstance();
    final savedOwner =
        jsonDecode(prefs.getString('ownedEncryptedFiles') ?? '{}') as Map;
    ownerRecords.addAll(
      savedOwner.map(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      ),
    );
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

  Future<void> saveOwnerRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ownedEncryptedFiles', jsonEncode(ownerRecords));
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
      // Animate the storage ring whenever a refresh completes
      _storageRingCtrl.forward(from: 0);
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
    EncryptedFile image,
  ) async {
    try {
      final r = await http
          .put(
            Uri.parse('${peer.base}/v1/files/$id'),
            body: image.ciphertext,
            headers: {
              'Content-Type': 'application/octet-stream',
              'x-hivenet-sha256': id,
              'x-hivenet-name': 'encrypted-object',
              'x-hivenet-mime': 'application/octet-stream',
              'x-hivenet-original-bytes': '${image.ciphertext.length}',
              'x-hivenet-delete-token-hash': image.deleteTokenHash,
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
      setState(() => status = 'Encrypting locally with AES-256-GCM...');
      final encrypted = await vault.encrypt(prepared.bytes);
      final id = encrypted.id;
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
      if (selectReplicaPeers(
            peers,
            candidate,
            encrypted.ciphertext.length,
          ).length !=
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
          encrypted.ciphertext.length,
        );
        if (next.isEmpty) break;
        final peer = next.first;
        attemptedKeys.add(peer.key);
        if (await send(peer, id, selected.name, encrypted)) {
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
      ownerRecords[id] = {
        'name': selected.name,
        'nonce': base64Url.encode(encrypted.nonce),
        'bytes': prepared.bytes.length,
        'originalBytes': prepared.originalBytes,
      };
      await saveOwnerRecords();
      if (kIsWeb) {
        await _webImages!.put(id, {
          'meta': {
            'id': id,
            'name': selected.name,
            'bytes': encrypted.ciphertext.length,
            'originalBytes': prepared.originalBytes,
          },
          'bytes': encrypted.ciphertext,
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
    final owner = ownerRecords[image.meta.id];
    if (owner == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This encrypted object belongs to another device.'),
          ),
        );
      }
      return;
    }
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
          final encrypted = _verifiedBytes(image.meta.id, response.bodyBytes);
          final plaintext = await vault.decrypt(
            image.meta.id,
            encrypted,
            base64Url.decode(owner['nonce'] as String),
          );
          await _showImage(owner['name'] as String, plaintext);
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

  // ─── helpers ──────────────────────────────────────────────────────────────

  String size(int n) => n > 1048576
      ? '${(n / 1048576).toStringAsFixed(1)} MB'
      : '${(n / 1024).toStringAsFixed(0)} KB';

  int get onlineCount => peers.where((p) => p.online).length;
  int get pooledFree =>
      peers.where((p) => p.online).fold(0, (n, p) => n + p.free);

  // ─── page builders ────────────────────────────────────────────────────────

  Widget _home(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Pull-to-refresh scroll view
          CustomScrollView(
            slivers: [
              // ── Gradient SliverAppBar ──
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    onPressed: busy ? null : refresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: addPeer,
                    icon: const Icon(Icons.add_link, color: Colors.white),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: const Text(
                    'HiveNet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 1.5,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff172832), Color(0xff0E1A21)],
                          ),
                        ),
                      ),
                      // Honeycomb decoration via CustomPaint
                      Positioned.fill(
                        child: CustomPaint(painter: _HoneycombPainter()),
                      ),
                      // Bottom blur fade
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (dark ? kDarkBg : const Color(0xffEEECFF))
                                    .withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // ── Node info card ──
                    GlassCard(
                      glowColor: kPurple,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => const LinearGradient(
                                  colors: [kPurple, kCyan],
                                ).createShader(b),
                                child: const Text(
                                  'THIS DEVICE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Colors.white,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              AnimatedStatusPill(
                                online: !busy,
                                label: busy ? 'Syncing' : 'Live',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            nodeId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: dark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? kCyan : kPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            PlatformNode.receiverDescription,
                            style: TextStyle(
                              fontSize: 11,
                              color: dark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Metric cards row ──
                    SizedBox(
                      height: 120,
                      child: Row(
                        children: [
                          Expanded(
                            child: GradientMetricCard(
                              icon: Icons.storage_outlined,
                              value: size(pooledFree),
                              label: 'Pooled storage',
                              colors: const [kPurple, kPink],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GradientMetricCard(
                              icon: Icons.devices_outlined,
                              value: '$onlineCount/${peers.length}',
                              label: 'Peers online',
                              colors: const [kCyan, kPurple],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GradientMetricCard(
                              icon: Icons.photo_library_outlined,
                              value: '${gallery.length}',
                              label: 'Gallery items',
                              colors: const [kPink, kAmber],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Peers section ──
                    NeonSectionTitle(
                      'Peers ($onlineCount/${peers.length} online)',
                      color: kCyan,
                    ),
                    ...peers.asMap().entries.map(
                      (entry) => _animatedPeerCard(c, entry.value, entry.key),
                    ),
                    if (peers.isEmpty)
                      GlassCard(
                        child: Text(
                          'No peers yet. Tap + to add a LAN peer.',
                          style: TextStyle(
                            color: dark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),

                    // ── Distributed gallery ──
                    NeonSectionTitle(
                      'Distributed Gallery (${gallery.length})',
                      color: kPink,
                    ),
                    if (gallery.isEmpty)
                      GlassCard(
                        glowColor: kPink,
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_outlined, color: kPink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No distributed images yet.',
                                style: TextStyle(
                                  color: dark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...gallery.map((entry) => _encryptedImageBar(c, entry)),

                    // ── Local gallery ──
                    NeonSectionTitle(
                      'Local Replicas (${images.length})',
                      color: kAmber,
                    ),
                    if (images.isEmpty)
                      GlassCard(
                        glowColor: kAmber,
                        child: const Text(
                          'No local replicas yet. This device becomes a '
                          'replica when another device uploads.',
                        ),
                      )
                    else
                      ...images.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            glowColor: kAmber,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [kAmber, kPink],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(m.name),
                              subtitle: Text(
                                '${size(m.bytes)} · ${m.id.substring(0, 10)}…',
                              ),
                              onTap: () => showImage(m),
                            ),
                          ),
                        ),
                      ),

                    if (lastCompression != null) ...[
                      const SizedBox(height: 8),
                      GlassCard(
                        glowColor: kGreen,
                        child: Row(
                          children: [
                            const Icon(Icons.compress, color: kGreen, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Last upload: $lastCompression',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // ── Upload busy overlay ──
          if (busy) _uploadOverlay(c),
        ],
      ),

      // ── Upload FAB ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: NeonButton(
          label: 'Upload Image',
          icon: Icons.upload_outlined,
          onPressed: busy ? null : upload,
          colors: const [kPurple, kCyan],
        ),
      ),
    );
  }

  /// Animated peer card with staggered opacity slide-in
  Widget _animatedPeerCard(BuildContext c, Peer p, int index) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 300 + index * 80),
        opacity: 1.0,
        child: GlassCard(
          glowColor: p.online ? kCyan : kRed,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: p.online ? [kCyan, kGreen] : [kRed, kPink],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                p.online ? Icons.check_circle_outline : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(p.id ?? p.host),
            subtitle: Text(
              '${p.host}:$_port'
              '${p.online ? ' · ${size(p.free)} free · ${p.latencyMs ?? '?'} ms · ${(p.reliability * 100).toStringAsFixed(0)}% reliable' : ' · offline'}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white54 : Colors.black54,
              ),
            ),
            onTap: p.online ? () => browsePeer(p) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Live' : 'Off',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    setState(() => peers.remove(p));
                    await savePeers();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Encrypted objects have no safe preview. Present their verifiable metadata
  /// as a compact file row instead of implying a readable image thumbnail.
  Widget _encryptedImageBar(BuildContext c, GalleryImage entry) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    final canOpen = ownerRecords.containsKey(entry.meta.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => showDistributedImage(entry),
        child: GlassCard(
          glowColor: kCyan,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kCyan.withOpacity(dark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kCyan.withOpacity(0.28)),
                ),
                child: Icon(
                  canOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: kCyan,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.meta.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${size(entry.meta.bytes)}  ·  ${entry.locations.length} verified replica${entry.locations.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: dark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      canOpen
                          ? 'AES-256-GCM · owned by this device'
                          : 'Encrypted object · access restricted',
                      style: const TextStyle(
                        fontSize: 10,
                        color: kCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                canOpen ? Icons.chevron_right_rounded : Icons.shield_outlined,
                color: dark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-screen upload overlay with HiveUploadAnimation
  Widget _uploadOverlay(BuildContext c) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: busy ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !busy,
        child: Container(
          color: Colors.black.withOpacity(0.75),
          child: Center(child: HiveUploadAnimation(statusText: status)),
        ),
      ),
    );
  }

  // ─── storage page ─────────────────────────────────────────────────────────

  Widget _storage(BuildContext c) {
    final totalFree = pooledFree;
    // Use a heuristic fraction for the ring (at most 0.85 for display)
    final usedFraction = peers.isEmpty ? 0.0 : 0.38.clamp(0.0, 0.85);
    final dark = Theme.of(c).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Storage', color: kPurple),

        // Animated ring
        GlassCard(
          glowColor: kPurple,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _storageRingCtrl,
                builder: (context, _) => SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: StorageRingPainter(
                      fraction: usedFraction,
                      progress: _storageRingCtrl.value,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                const LinearGradient(colors: [kPurple, kCyan])
                                    .createShader(b),
                            child: Text(
                              size(totalFree),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'pooled free',
                            style: TextStyle(fontSize: 12, color: kCyan),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(kPurple, 'Used'),
                  const SizedBox(width: 20),
                  _legendDot(kCyan, 'Free'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        NeonSectionTitle('Node Capacity', color: kCyan),
        ...peers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              glowColor: p.online ? kCyan : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.storage_outlined,
                  color: p.online ? kCyan : kRed,
                ),
                title: Text(p.id ?? p.host),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.online
                          ? '${size(p.free)} available · ${p.host}:$_port'
                          : '${p.host}:$_port unavailable',
                    ),
                    if (p.online) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.free > 0
                              ? (1 - p.free / (p.free + 1024 * 1024)).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0,
                          backgroundColor: dark
                              ? Colors.white12
                              : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            kCyan,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Live' : 'Offline',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  // ─── peers page ───────────────────────────────────────────────────────────

  Widget _peers(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Peers', color: kCyan),
        Text(
          'Live network telemetry · tap a connected peer to browse its files.',
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        ...peers.asMap().entries.map((entry) {
          final p = entry.value;
          final reliability = p.reliability;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              glowColor: p.online ? kCyan : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: p.online ? () => browsePeer(p) : null,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: p.online ? [kCyan, kGreen] : [kRed, kPink],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    p.online
                        ? Icons.lan_outlined
                        : Icons.portable_wifi_off_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(p.id ?? p.host),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.host}:$_port · ${p.online ? '${p.latencyMs ?? '?'} ms' : 'Offline'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (p.online) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text(
                            'Latency  ',
                            style: TextStyle(fontSize: 10),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((p.latencyMs ?? 500) / 500).clamp(
                                  0.0,
                                  1.0,
                                ),
                                backgroundColor: dark
                                    ? Colors.white12
                                    : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kAmber,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Text(
                            'Reliability',
                            style: TextStyle(fontSize: 10),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: reliability,
                                backgroundColor: dark
                                    ? Colors.white12
                                    : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kGreen,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                isThreeLine: p.online,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    setState(() => peers.remove(p));
                    await savePeers();
                  },
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── gallery page ─────────────────────────────────────────────────────────

  Widget _gallery(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Gallery', color: kPink),
        Text(
          '${gallery.length} encrypted objects across responsive peers. '
          'Previews stay private; only verified metadata is shown here.',
        ),
        const SizedBox(height: 12),
        if (gallery.isEmpty)
          GlassCard(
            glowColor: kPink,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, color: kPink, size: 48),
                    SizedBox(height: 12),
                    Text('No distributed images yet.'),
                  ],
                ),
              ),
            ),
          )
        else
          ...gallery.map((entry) => _encryptedImageBar(c, entry)),
        /* Legacy thumbnail grid, deliberately not used for encrypted files.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: gallery.length,
            itemBuilder: (c, i) {
              final g = gallery[i];
              return GestureDetector(
                onTap: () => showDistributedImage(g),
                child: GlassCard(
                  glowColor: kPink,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ShimmerBox(height: double.infinity),
                              const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        g.meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${size(g.meta.bytes)} · ${g.locations.length} replica(s)',
                        style: const TextStyle(fontSize: 10, color: kCyan),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          */
      ],
    );
  }

  // ─── router page ──────────────────────────────────────────────────────────

  Widget _router(BuildContext c) {
    final selected = selectReplicaPeers(
      peers,
      (p) => PeerCandidate(
        key: p.key,
        freeBytes: p.free,
        latencyMs: p.latencyMs,
        online: p.online,
        successes: p.successes,
        failures: p.failures,
      ),
      0,
    );
    final dark = Theme.of(c).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Smart Router', color: kAmber),

        // Animated topology diagram
        GlassCard(
          glowColor: kAmber,
          padding: const EdgeInsets.all(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _routerAnimCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: RouterTopologyPainter(
                          _routerAnimCtrl.value,
                          onlinePeers: onlineCount,
                          totalPeers: peers.length,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 18,
                    child: Row(
                      children: const [
                        PulsingDot(color: kCyan, size: 6),
                        SizedBox(width: 7),
                        Text(
                          'LIVE ROUTES',
                          style: TextStyle(
                            color: kCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Text(
                      'LOCAL COORDINATOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        GlassCard(
          glowColor: kAmber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: kAmber),
                  const SizedBox(width: 10),
                  const Text(
                    'Two independent replicas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  AnimatedStatusPill(
                    online: selected.length == 2,
                    label: selected.length == 2 ? 'Ready' : 'Needs peers',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Scores use actual free space, probe latency, availability, and verified-transfer reliability.',
                style: TextStyle(
                  color: dark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              ...selected.asMap().entries.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPurple, kCyan]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  title: Text(e.value.id ?? e.value.host),
                  subtitle: Text(
                    '${size(e.value.free)} free · ${e.value.latencyMs ?? '?'} ms · ${(e.value.reliability * 100).toStringAsFixed(0)}% reliable',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        NeonSectionTitle('Eligible Peer Telemetry', color: kCyan),
        ...peers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              glowColor: p.online ? kGreen : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Eligible' : 'Offline',
                ),
                title: Text(p.id ?? p.host),
                trailing: Text(
                  p.online ? '${p.latencyMs ?? '?'} ms' : '—',
                  style: TextStyle(
                    color: p.online ? kCyan : kRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── settings page ────────────────────────────────────────────────────────

  Widget _settings(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Settings', color: kPurple),

        GlassCard(
          glowColor: kPurple,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [kPurple, kCyan])
                      .createShader(b),
              child: const Text(
                'Dark Theme',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            subtitle: const Text('Use HiveNet\'s cyberpunk dark palette.'),
            value: themeMode.value == ThemeMode.dark,
            onChanged: (v) =>
                themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
            activeColor: kPurple,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kCyan,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.network_check_outlined, color: kCyan),
            title: const Text(
              'Run Diagnostics',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(status),
            onTap: refresh,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kAmber,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.repeat_rounded, color: kAmber),
            title: Text(
              'Replication Factor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Two independent verified replicas'),
            trailing: Text(
              '2',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: kAmber,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kGreen,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.memory_outlined, color: kGreen),
            title: const Text(
              'This Device',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${PlatformNode.receiverDescription}\n$nodeId'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kPink,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_user_outlined, color: kPink),
            title: Text(
              'End-to-End Encryption',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('AES-256-GCM · SHA-256 content addressing'),
          ),
        ),
      ],
    );
  }

  // ─── _tab variable + build ────────────────────────────────────────────────

  int _tab = 0;

  @override
  Widget build(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;

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
    const selectedIcons = [
      Icons.home_rounded,
      Icons.storage_rounded,
      Icons.devices_rounded,
      Icons.photo_library_rounded,
      Icons.account_tree_rounded,
      Icons.settings_rounded,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated shifting gradient background ──
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, _) {
              final t = _bgAnimationController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.7 + t * 0.25, -0.9 + t * 0.18),
                    radius: 1.25,
                    colors: dark
                        ? [
                            kDarkSurface,
                            Color.lerp(kDarkBg, kCyan.withOpacity(0.16), t)!,
                            kDarkBg,
                          ]
                        : [
                            const Color(0xffF8FAF9),
                            Color.lerp(
                              const Color(0xffEEF2F0),
                              kCyan.withOpacity(0.07),
                              t * 0.35,
                            )!,
                            const Color(0xffEEF2F0),
                          ],
                  ),
                ),
              );
            },
          ),

          // ── Page content with animated tab switch ──
          TabTransitionWrapper(tabIndex: _tab, child: pages[_tab]),

          // ── Floating frosted glass navigation bar ──
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xff132129).withOpacity(0.97)
                        : Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: dark
                          ? kCyan.withOpacity(0.30)
                          : const Color(0xff203B43).withOpacity(0.18),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(dark ? 0.36 : 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(6, (i) {
                        final selected = _tab == i;
                        return GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: selected
                                  ? kCyan.withOpacity(dark ? 0.24 : 0.14)
                                  : Colors.transparent,
                              border: selected
                                  ? Border.all(
                                      color: kCyan.withOpacity(
                                        dark ? 0.52 : 0.34,
                                      ),
                                    )
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: kCyan.withOpacity(0.18),
                                        blurRadius: 12,
                                        spreadRadius: -4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected ? selectedIcons[i] : icons[i],
                                  color: selected
                                      ? kCyan
                                      : (dark
                                            ? Colors.white70
                                            : Colors.black54),
                                  size: 24,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? kCyan
                                        : (dark
                                              ? Colors.white70
                                              : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HoneycombPainter  –  decorative header background
// ─────────────────────────────────────────────────────────────────────────────
class _HoneycombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.18);

    const r = 28.0; // hex radius
    const dx = r * 1.732; // horizontal step
    const dy = r * 1.5; // vertical step

    for (var row = -1; row < size.height / dy + 2; row++) {
      for (var col = -1; col < size.width / dx + 2; col++) {
        final cx = col * dx + (row.isOdd ? dx / 2 : 0);
        final cy = row * dy;
        _drawHex(canvas, Offset(cx, cy), r, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    const sides = 6;
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = (i * 60 - 30) * (3.14159265358979 / 180);
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HoneycombPainter _) => false;
}
