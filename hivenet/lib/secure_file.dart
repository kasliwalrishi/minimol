import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owner-only encrypted file envelope. Peers receive [ciphertext] only.
class EncryptedFile {
  const EncryptedFile({
    required this.id,
    required this.ciphertext,
    required this.nonce,
    required this.deleteToken,
  });
  final String id;
  final Uint8List ciphertext;
  final List<int> nonce;
  final String deleteToken;
  String get deleteTokenHash =>
      sha256.convert(utf8.encode(deleteToken)).toString();
}

/// Per-file AES-256-GCM keys are retained only in platform secure storage.
class OwnerVault {
  OwnerVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  final _cipher = AesGcm.with256bits();

  Future<EncryptedFile> encrypt(List<int> plaintext) async {
    final key = await _cipher.newSecretKey();
    final keyBytes = await key.extractBytes();
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(plaintext, secretKey: key, nonce: nonce);
    final bytes = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    final id = sha256.convert(bytes).toString();
    final token = base64Url.encode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(
      key: 'hivenet.key.$id',
      value: base64Url.encode(keyBytes),
    );
    await _storage.write(key: 'hivenet.delete.$id', value: token);
    return EncryptedFile(
      id: id,
      ciphertext: bytes,
      nonce: nonce,
      deleteToken: token,
    );
  }

  Future<Uint8List> decrypt(
    String id,
    List<int> ciphertext,
    List<int> nonce,
  ) async {
    final raw = await _storage.read(key: 'hivenet.key.$id');
    if (raw == null) {
      throw StateError('This device does not own the decryption key.');
    }
    final key = SecretKey(base64Url.decode(raw));
    if (ciphertext.length < 16) {
      throw const FormatException('Encrypted object is truncated.');
    }
    final split = ciphertext.length - 16;
    final box = SecretBox(
      ciphertext.sublist(0, split),
      nonce: nonce,
      mac: Mac(ciphertext.sublist(split)),
    );
    return Uint8List.fromList(await _cipher.decrypt(box, secretKey: key));
  }

  Future<void> forget(String id) async {
    await _storage.delete(key: 'hivenet.key.$id');
    await _storage.delete(key: 'hivenet.delete.$id');
  }
}
