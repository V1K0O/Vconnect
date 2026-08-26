import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  Future<bool> requestAllPermissions() async {
    final statuses = await [
      Permission.nearbyWifiDevices,
      Permission.photos,
      Permission.videos,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
}