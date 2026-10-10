import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// A release found on GitHub that is newer than the installed build.
class UpdateInfo {
  final String version; // e.g. "1.1.0"
  final String notes;
  final String apkUrl;
  final int apkSizeBytes;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkSizeBytes,
  });
}

enum InstallOutcome { started, permissionRequired, downloadFailed, error }

/// Checks GitHub Releases for a newer build and drives the download +
/// install flow, so updating FrenchPass never requires the learner to find
/// and sideload an APK by hand.
///
/// This is deliberately not a silent background updater: Android has no API
/// for a sideloaded app to replace itself without the system's install
/// confirmation screen, so the best available flow is "detect automatically,
/// download automatically, then one tap through Android's own installer".
class UpdateService {
  static const _owner = 'LuisfNarvaez01';
  static const _repo = 'FrenchPass';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const _installerChannel = MethodChannel('com.frenchpass/installer');

  final ValueNotifier<UpdateInfo?> available = ValueNotifier(null);
  final ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  /// Fetches the latest release and updates [available] if it is newer than
  /// the running build. Never throws — a failed check (offline, rate limit,
  /// malformed release) just means no update is reported this session.
  Future<void> checkInBackground() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .get(Uri.parse(_apiUrl), headers: const {
            'Accept': 'application/vnd.github+json',
          })
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final remoteVersion = tag.replaceFirst(RegExp(r'^v'), '').trim();
      if (remoteVersion.isEmpty) return;
      if (!isNewerVersion(remoteVersion, info.version)) return;

      final assets = (json['assets'] as List?) ?? const [];
      Map<String, dynamic>? pick(bool Function(String name) match) {
        for (final a in assets) {
          final asset = a as Map<String, dynamic>;
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk') && match(name)) return asset;
        }
        return null;
      }

      final asset = pick((n) => n.contains('arm64')) ??
          pick((n) => n.contains('universal')) ??
          pick((_) => true);
      if (asset == null) return;

      available.value = UpdateInfo(
        version: remoteVersion,
        notes: (json['body'] as String?)?.trim() ?? '',
        apkUrl: asset['browser_download_url'] as String,
        apkSizeBytes: (asset['size'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('UpdateService.checkInBackground failed: $e');
    }
  }

  /// Simple dotted-version comparison; `remote > local` → true. Falls back to
  /// treating a malformed segment as 0, so "1.2" vs "1.2.1" still compares.
  @visibleForTesting
  static bool isNewerVersion(String remote, String local) {
    final r = remote.split('+').first.split('.').map(_toInt).toList();
    final l = local.split('+').first.split('.').map(_toInt).toList();
    final len = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  static int _toInt(String s) => int.tryParse(s.trim()) ?? 0;

  /// Downloads [info]'s APK into the app's cache dir, reporting progress via
  /// [downloadProgress] (0–1, or null when idle), then hands it to the
  /// platform installer. Returns how far the flow got.
  Future<InstallOutcome> downloadAndInstall(UpdateInfo info) async {
    File? file;
    try {
      downloadProgress.value = 0;
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        downloadProgress.value = null;
        return InstallOutcome.downloadFailed;
      }

      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/frenchpass-update.apk');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength ?? info.apkSizeBytes;

      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) downloadProgress.value = received / total;
      }).asFuture<void>();
      await sink.close();
      downloadProgress.value = 1;
    } catch (e) {
      debugPrint('UpdateService.downloadAndInstall failed: $e');
      downloadProgress.value = null;
      return InstallOutcome.downloadFailed;
    }

    try {
      final canInstall =
          await _installerChannel.invokeMethod<bool>('canInstallPackages') ??
              false;
      if (!canInstall) {
        await _installerChannel.invokeMethod('requestInstallPermission');
        downloadProgress.value = null;
        return InstallOutcome.permissionRequired;
      }

      await _installerChannel.invokeMethod('installApk', {'path': file.path});
      downloadProgress.value = null;
      return InstallOutcome.started;
    } catch (e) {
      debugPrint('UpdateService.installApk failed: $e');
      downloadProgress.value = null;
      return InstallOutcome.error;
    }
  }

  /// Call once permission has been granted from Settings, to retry the
  /// install step without downloading again.
  Future<InstallOutcome> retryInstall() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/frenchpass-update.apk');
      if (!await file.exists()) return InstallOutcome.downloadFailed;

      final canInstall =
          await _installerChannel.invokeMethod<bool>('canInstallPackages') ??
              false;
      if (!canInstall) return InstallOutcome.permissionRequired;

      await _installerChannel.invokeMethod('installApk', {'path': file.path});
      return InstallOutcome.started;
    } catch (e) {
      debugPrint('UpdateService.retryInstall failed: $e');
      return InstallOutcome.error;
    }
  }
}
