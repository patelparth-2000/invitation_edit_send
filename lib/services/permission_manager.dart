import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  /// Requests the camera permission and returns the resulting status, so the
  /// caller can tell "denied" from "permanently denied" (U-6).
  static Future<PermissionStatus> requestCameraPermission() =>
      Permission.camera.request();

  static Future<bool> openSettings() => openAppSettings();
}
