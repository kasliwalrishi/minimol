import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class PlatformNode {
  static const _channel = MethodChannel('com.hivenet.hivenet/node');
  static bool get canReceiveLanReplicas => true;
  static String get receiverDescription => 'Local receiver: port 8765';
  static Future<void> start(String nodeId) {
    // `dart.library.io` also selects this implementation for desktop and iOS.
    // Only Android has the foreground-service MethodChannel implementation.
    if (!Platform.isAndroid) return Future.value();
    return _channel.invokeMethod<void>('startNode', {'nodeId': nodeId});
  }
}
