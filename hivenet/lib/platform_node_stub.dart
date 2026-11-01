class PlatformNode {
  static bool get canReceiveLanReplicas => false;
  static String get receiverDescription =>
      'Receiver unavailable on this platform';
  static Future<void> start(String nodeId) async {}
}
