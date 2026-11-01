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

const _port = 8765;
void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'HiveNet',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      useMaterial3: true,
    ),
    home: const Dashboard(),
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
  var nodeId = '';
  var busy = true;
  var status = 'Starting node...';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Replicated and verified on both storage nodes.'),
          ),
        );
      }
    } catch (e) {
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
  @override
  Widget build(BuildContext c) => Scaffold(
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
          Card(
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
            (p) => Card(
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
            (entry) => Card(
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
            (m) => Card(
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
}
