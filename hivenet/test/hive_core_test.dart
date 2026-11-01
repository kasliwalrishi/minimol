import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivenet/hive_core.dart';
import 'package:image/image.dart' as image;

void main() {
  test(
    'compression resizes, reduces a large image, and has a stable SHA-256 ID',
    () {
      final source = image.Image(width: 3000, height: 2000);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, x % 255, y % 255, (x + y) % 255);
        }
      }
      final input = Uint8List.fromList(image.encodePng(source));
      final compressed = compressImage(input);
      expect(compressed.width, 1920);
      expect(compressed.height, 1280);
      expect(compressed.bytes, isNotEmpty);
      expect(compressed.id, hasLength(64));
      expect(matchesContentId(compressed.id, compressed.bytes), isTrue);
      expect(matchesContentId(compressed.id, [1, 2, 3]), isFalse);
    },
  );

  test('router selects two distinct online peers with capacity', () {
    final peers = [
      const PeerCandidate(
        key: 'a',
        freeBytes: 8 << 30,
        latencyMs: 5,
        online: true,
        successes: 10,
        failures: 0,
      ),
      const PeerCandidate(
        key: 'b',
        freeBytes: 6 << 30,
        latencyMs: 10,
        online: true,
        successes: 8,
        failures: 1,
      ),
      const PeerCandidate(
        key: 'c',
        freeBytes: 1,
        latencyMs: 1,
        online: true,
        successes: 20,
        failures: 0,
      ),
      const PeerCandidate(
        key: 'd',
        freeBytes: 9 << 30,
        latencyMs: 1,
        online: false,
        successes: 20,
        failures: 0,
      ),
    ];
    final selected = selectReplicaPeers(peers, (peer) => peer, 1024);
    expect(selected.map((peer) => peer.key), ['a', 'b']);
  });
}
