class PlatformNode {
  // Browsers cannot bind a TCP port or accept unsolicited LAN connections.
  static bool get canReceiveLanReplicas => false;
  static String get receiverDescription =>
      'Browser client: uploads and retrieves via Android peers';
  static Future<void> start(String nodeId) async {}
}
