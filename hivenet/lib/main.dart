import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String get base => 'http://$host:$_port';
}

class Meta {
  Meta(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String? ?? 'image.jpg',
      bytes = (j['bytes'] as num).toInt();
  final String id, name;
  final int bytes;
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
    for (final host in (jsonDecode(prefs.getString('peers') ?? '[]') as List)) {
      peers.add(Peer(host as String));
    }
    // A foreground receiver is native because a Flutter activity may be
    // paused or destroyed while another LAN node uploads a replica.
    await PlatformNode.start(nodeId);
    await refresh();
  }

  Future<void> savePeers() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('peers', jsonEncode(peers.map((e) => e.host).toList()));
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
          final r = await get('${p.base}/v1/info');
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body) as Map<String, dynamic>;
            p.online = true;
            p.id = j['nodeId'] as String?;
            p.free = (j['freeBytes'] as num?)?.toInt() ?? 0;
          } else {
            p.online = false;
          }
        } catch (_) {
          p.online = false;
        }
      }),
    );
    if (kIsWeb) {
      images = _webImages!.values
          .map((e) => Meta(Map<String, dynamic>.from(e['meta'] as Map)))
          .toList();
    } else {
      try {
        final r = await get('http://127.0.0.1:$_port/v1/files');
        if (r.statusCode == 200) {
          images = (jsonDecode(r.body) as List)
              .map((e) => Meta(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        busy = false;
        status = 'Node active on port $_port';
      });
    }
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

  Future<bool> send(Peer peer, String id, String name, List<int> bytes) async {
    final r = await http
        .put(
          Uri.parse('${peer.base}/v1/files/$id'),
          body: bytes,
          headers: {
            'Content-Type': 'image/jpeg',
            'x-hivenet-sha256': id,
            'x-hivenet-name': Uri.encodeComponent(name),
            'x-hivenet-mime': 'image/jpeg',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 201) return false;
    final ack = jsonDecode(r.body) as Map<String, dynamic>;
    return ack['stored'] == true && ack['sha256'] == id;
  }

  Future<void> upload() async {
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    setState(() {
      busy = true;
      status = 'Compressing image...';
    });
    try {
      final decoded = image.decodeImage(await selected.readAsBytes());
      if (decoded == null) throw Exception('Unsupported image');
      final bytes = image.encodeJpg(decoded, quality: 78);
      final id = sha256.convert(bytes).toString();
      // Prefer the peers with the most free disk space and never count the
      // same node twice (for example when it was entered by two LAN aliases).
      final candidates = peers.where((p) => p.online).toList()
        ..sort((a, b) => b.free.compareTo(a.free));
      final selectedIds = <String>{};
      final targets = candidates
          .where((p) => selectedIds.add(p.id ?? p.host))
          .take(2)
          .toList();
      if (targets.length != 2) {
        throw Exception(
          'Exactly two online peers are required (${targets.length} found).',
        );
      }
      setState(() => status = 'Replicating to two storage nodes...');
      final acks = await Future.wait(
        targets.map((p) => send(p, id, selected.name, bytes)),
      );
      if (!acks.every((x) => x)) {
        throw Exception('A node rejected the checksum; upload not confirmed.');
      }
      if (kIsWeb) {
        await _webImages!.put(id, {
          'meta': {'id': id, 'name': selected.name, 'bytes': bytes.length},
          'bytes': bytes,
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

  /// A retrieval is only displayed when it still matches its content address.
  /// Android verifies on receipt too; this catches corruption in transit or at
  /// rest before a peer's image is rendered on either platform.
  Uint8List _verifiedBytes(String id, List<int> bytes) {
    final imageBytes = Uint8List.fromList(bytes);
    if (sha256.convert(imageBytes).toString() != id) {
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
                  '${p.host}:$_port${p.online ? ' - ${size(p.free)} free' : ' - offline'}',
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
