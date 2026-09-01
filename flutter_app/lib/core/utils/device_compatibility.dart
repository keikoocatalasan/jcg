import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

/// Checks whether Google Play Services is available on this device.
/// Returns false on Huawei without GMS, custom ROMs, or sandboxed devices.
Future<bool> checkGooglePlayServicesAvailable() async {
  try {
    final googleSignIn = GoogleSignIn(scopes: ['email']);
    await googleSignIn.signInSilently();
    return true;
  } on PlatformException catch (e) {
    final code = e.code.toLowerCase();
    if (code.contains('network_error') ||
        code.contains('sign_in_failed') ||
        code.contains('play_services')) {
      return false;
    }
    return true;
  } catch (_) {
    return true;
  }
}

/// Checks whether the device has any usable cameras.
Future<bool> checkCameraAvailable() async {
  try {
    final cameras = await availableCameras();
    return cameras.isNotEmpty;
  } on CameraException {
    return false;
  } catch (_) {
    return false;
  }
}

/// Returns true for low-end devices where we should reduce animations,
/// image resolution, and timeout durations.
Future<bool> checkIsLowEndDevice() async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // Heuristic: < 3 GB RAM or API < 26 usually means low-end.
      // device_info_plus on Android does not expose RAM directly,
      // so we use a conservative API-based fallback.
      if (androidInfo.version.sdkInt < 26) return true;
      // If the device is 32-bit only, it's likely low-end.
      if (!androidInfo.supported64BitAbis.contains('arm64-v8a')) {
        // Check if it's actually a 32-bit device (not just an emulator with both)
        if (androidInfo.supported64BitAbis.isEmpty) return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
