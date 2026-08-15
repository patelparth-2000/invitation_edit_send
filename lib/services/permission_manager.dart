import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  /// Request permission for a specific [Permission]
  static Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status == PermissionStatus.granted;
  }

  /// Request Camera Permission
  static Future<bool> requestCameraPermission() async {
    return await requestPermission(Permission.camera);
  }

  /// Request Gallery Permission (Storage Permission)
  static Future<bool> requestGalleryPermission() async {
    return await requestPermission(Permission.photos);
  }

  /// Request Microphone Permission
  static Future<bool> requestMicrophonePermission() async {
    return await requestPermission(Permission.microphone);
  }

  /// Request Audio Permission
  static Future<bool> requestAudioPermission() async {
    return await requestPermission(Permission.speech);
  }

  static Future<bool> requestMediaLibraryPermission() async {
    return await requestPermission(Permission.mediaLibrary);
  }

  static Future<bool> requestExternalStoragePermission() async {
    return await requestPermission(Permission.manageExternalStorage);
  }

  /// Request Multiple Permissions
  static Future<bool> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
      // Permission.microphone,
      // Permission.speech,
    ].request();

    return statuses.values
        .every((status) => status == PermissionStatus.granted);
  }
}
