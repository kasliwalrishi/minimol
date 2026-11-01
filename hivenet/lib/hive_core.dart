import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

/// The result of the client-side, deterministic image preparation step.
class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.originalBytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int originalBytes;
  final int width;
  final int height;
  String get id => sha256.convert(bytes).toString();
  double get ratio => originalBytes == 0 ? 1 : bytes.length / originalBytes;
}

bool matchesContentId(String id, List<int> bytes) =>
    sha256.convert(bytes).toString() == id;

/// Decodes, constrains the longest edge, and encodes an interoperable JPEG.
/// Keeping this pure makes the same bytes/hash available on Android and web.
CompressedImage compressImage(List<int> source, {int longestEdge = 1920}) {
  final decoded = image.decodeImage(Uint8List.fromList(source));
  if (decoded == null) throw const FormatException('Unsupported image format.');
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longest > longestEdge
      ? image.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? longestEdge : null,
          height: decoded.height > decoded.width ? longestEdge : null,
        )
      : decoded;
  return CompressedImage(
    bytes: Uint8List.fromList(image.encodeJpg(resized, quality: 78)),
    originalBytes: source.length,
    width: resized.width,
    height: resized.height,
  );
}

/// Input from a real `/v1/info` probe plus transfer history persisted locally.
class PeerCandidate {
  const PeerCandidate({
    required this.key,
    required this.freeBytes,
    required this.latencyMs,
    required this.online,
    required this.successes,
    required this.failures,
  });

  final String key;
  final int freeBytes;
  final int? latencyMs;
  final bool online;
  final int successes;
  final int failures;

  double get reliability {
    final attempts = successes + failures;
    // Unknown peers are neutral instead of being treated as proven reliable.
    return attempts == 0 ? .5 : successes / attempts;
  }

  double scoreFor(int bytes) {
    if (!online || freeBytes < bytes) return double.negativeInfinity;
    final capacity = (freeBytes / (1024 * 1024 * 1024))
        .clamp(0, 100)
        .toDouble();
    final latency = latencyMs == null
        ? 0.0
        : (100 - latencyMs!.clamp(0, 100)).toDouble();
    return capacity * .45 + latency * .25 + reliability * 100 * .30;
  }
}

/// Selects exactly two *distinct* devices. It never falls back to broadcast.
List<T> selectReplicaPeers<T>(
  Iterable<T> peers,
  PeerCandidate Function(T peer) candidate,
  int bytes,
) {
  final ranked =
      peers.where((peer) => candidate(peer).scoreFor(bytes).isFinite).toList()
        ..sort((a, b) {
          final aCandidate = candidate(a);
          final bCandidate = candidate(b);
          final byScore = bCandidate
              .scoreFor(bytes)
              .compareTo(aCandidate.scoreFor(bytes));
          return byScore != 0
              ? byScore
              : aCandidate.key.compareTo(bCandidate.key);
        });
  final used = <String>{};
  return ranked.where((peer) => used.add(candidate(peer).key)).take(2).toList();
}
