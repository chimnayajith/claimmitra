import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.notes, required this.downloadUrl});
  final String version;
  final String notes;
  final String downloadUrl;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const repository = 'chimnayajith/claimmitra';
  static const currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.9');
  String? lastCheckFailure;

  Future<AvailableUpdate?> checkForUpdate() async {
    lastCheckFailure = null;
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'ClaimMitra-Updater'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        lastCheckFailure = 'GitHub returned HTTP ${response.statusCode}.';
        debugPrint('ClaimMitra update check failed: $lastCheckFailure');
        return null;
      }
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (release['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      if (tag.isEmpty) {
        lastCheckFailure = 'GitHub returned no release version.';
        return null;
      }
      debugPrint('ClaimMitra update check: local=$currentVersion remote=$tag');
      if (!_isNewer(tag, currentVersion)) return null;
      final assets = (release['assets'] as List<dynamic>? ?? const []);
      final installer = assets.cast<Map<String, dynamic>>().where((asset) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        return name.endsWith('.exe') && name.contains('claimmitra-setup');
      }).firstOrNull;
      final url = installer?['browser_download_url'] as String?;
      if (url == null || url.isEmpty) {
        lastCheckFailure = 'The latest release has no ClaimMitra installer asset.';
        return null;
      }
      return AvailableUpdate(
        version: tag,
        notes: (release['body'] as String? ?? '').trim(),
        downloadUrl: url,
      );
    } catch (error) {
      // Update checks must never prevent offline use.
      lastCheckFailure = error.toString();
      debugPrint('ClaimMitra update check skipped: $error');
      return null;
    }
  }

  static bool isNewerVersion(String remote, String local) {
    List<int> parse(String version) => version.split('+').first.split('.').map((part) {
      final match = RegExp(r'^\d+').firstMatch(part.trim());
      return int.tryParse(match?.group(0) ?? '') ?? 0;
    }).toList();
    final a = parse(remote);
    final b = parse(local);
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  bool _isNewer(String remote, String local) => isNewerVersion(remote, local);

  Future<void> downloadAndInstall(
    AvailableUpdate update, {
    void Function(double? progress)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('In-app updates are only available on Windows.');
    }

    final safeVersion = update.version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '_',
    );
    final installerPath = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'ClaimMitra-Setup-$safeVersion.exe';
    final installerFile = File(installerPath);
    if (await installerFile.exists()) {
      await installerFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(update.downloadUrl));
      final response = await client.send(request).timeout(
        const Duration(minutes: 10),
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'Installer download failed with HTTP ${response.statusCode}.',
        );
      }

      final sink = installerFile.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          final total = response.contentLength;
          onProgress?.call(
            total == null || total <= 0 ? null : received / total,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    if (!await installerFile.exists() || await installerFile.length() == 0) {
      throw const FileSystemException('The downloaded installer was empty.');
    }

    final appPath = Platform.resolvedExecutable;
    String quotePowerShell(String value) => "'${value.replaceAll("'", "''")}'";
    final script = '''
\$appPid = $pid;
Wait-Process -Id \$appPid -ErrorAction SilentlyContinue;
Start-Process -FilePath ${quotePowerShell(installerPath)} -ArgumentList '/SILENT','/NORESTART' -Wait;
Start-Process -FilePath ${quotePowerShell(appPath)};
Remove-Item -LiteralPath ${quotePowerShell(installerPath)} -Force -ErrorAction SilentlyContinue;
''';
    await Process.start(
      'powershell.exe',
      [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}
