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
  static const currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.3+6');

  Future<AvailableUpdate?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'ClaimMitra-Updater'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (release['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      if (tag.isEmpty || !_isNewer(tag, currentVersion)) return null;
      final assets = (release['assets'] as List<dynamic>? ?? const []);
      final installer = assets.cast<Map<String, dynamic>>().where((asset) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        return name.endsWith('.exe') && name.contains('claimmitra-setup');
      }).firstOrNull;
      final url = installer?['browser_download_url'] as String? ??
          release['html_url'] as String? ??
          'https://github.com/$repository/releases/latest';
      return AvailableUpdate(
        version: tag,
        notes: (release['body'] as String? ?? '').trim(),
        downloadUrl: url,
      );
    } catch (error) {
      // Update checks must never prevent offline use.
      debugPrint('ClaimMitra update check skipped: $error');
      return null;
    }
  }

  bool _isNewer(String remote, String local) {
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

  Future<void> openDownload(String url) async {
    if (!Platform.isWindows) return;
    await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
  }
}
