import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Offline verification plus online, one-computer activation for ClaimMitra.
/// Configure with --dart-define=SUPABASE_URL=...,
/// --dart-define=SUPABASE_ANON_KEY=..., and
/// --dart-define=LICENSE_PUBLIC_KEY_B64=... .
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _publicKeyB64 = String.fromEnvironment('LICENSE_PUBLIC_KEY_B64');
  static const _licenseFilename = 'claimmitra.license';

  final Ed25519 _ed25519 = Ed25519();

  bool get isConfigured =>
      _supabaseUrl.startsWith('https://') &&
      _supabaseAnonKey.isNotEmpty &&
      _publicKeyB64.isNotEmpty;

  Future<File> _licenseFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, _licenseFilename));
  }

  Future<String> machineFingerprint() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('ClaimMitra licensing currently supports Windows only.');
    }
    final result = await Process.run('reg', [
      'query',
      r'HKLM\SOFTWARE\Microsoft\Cryptography',
      '/v',
      'MachineGuid',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw StateError('Could not read this Windows installation ID.');
    }
    final output = '${result.stdout}';
    final match = RegExp(r'MachineGuid\s+REG_SZ\s+([^\r\n]+)', caseSensitive: false)
        .firstMatch(output);
    final machineGuid = match?.group(1)?.trim();
    if (machineGuid == null || machineGuid.isEmpty) {
      throw StateError('Windows did not return a machine ID.');
    }
    // Do not transmit the raw Windows MachineGuid.
    return sha256.convert(utf8.encode('ClaimMitra-v1:$machineGuid')).toString();
  }

  Future<bool> hasValidLocalLicense() async {
    // Keep local development usable without a production licence.
    if (kDebugMode) return true;
    try {
      final file = await _licenseFile();
      if (!await file.exists() || !isConfigured) return false;
      final token = (await file.readAsString()).trim();
      final payload = await _verifyToken(token);
      if (payload == null) return false;
      return payload['product'] == 'ClaimMitra' &&
          payload['machine_hash'] == await machineFingerprint() &&
          payload['license_id'] is String &&
          payload['issued_at'] is String;
    } catch (error) {
      debugPrint('Local licence validation failed: $error');
      return false;
    }
  }

  Future<void> activate(String licenseKey) async {
    if (!isConfigured) {
      throw StateError('Licensing is not configured in this build.');
    }
    if (licenseKey.trim().isEmpty) {
      throw ArgumentError('Enter your licence key.');
    }
    final machineHash = await machineFingerprint();
    final baseUrl = _supabaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await http
        .post(
          Uri.parse('$baseUrl/functions/v1/activate'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _supabaseAnonKey,
          },
          body: jsonEncode({'license_key': licenseKey.trim(), 'machine_hash': machineHash}),
        )
        .timeout(const Duration(seconds: 20));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('The licensing service returned an invalid response.');
    }
    if (response.statusCode != 200) {
      throw StateError(body['error']?.toString() ?? 'Activation failed.');
    }
    final token = body['license_token'];
    if (token is! String || token.isEmpty) {
      throw StateError('The licensing service did not return a licence.');
    }
    final payload = await _verifyToken(token);
    if (payload == null ||
        payload['product'] != 'ClaimMitra' ||
        payload['machine_hash'] != machineHash ||
        payload['license_id'] is! String) {
      throw StateError('The returned licence could not be verified on this computer.');
    }
    final file = await _licenseFile();
    await file.writeAsString(token, flush: true);
  }

  Future<Map<String, dynamic>?> _verifyToken(String token) async {
    if (!isConfigured) return null;
    final parts = token.split('.');
    if (parts.length != 2) return null;
    final payloadBytes = _decodeBase64Url(parts[0]);
    final signatureBytes = _decodeBase64Url(parts[1]);
    final publicKeyBytes = base64.decode(_publicKeyB64);
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) return null;
    final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(signatureBytes, publicKey: publicKey);
    final valid = await _ed25519.verify(payloadBytes, signature: signature);
    if (!valid) return null;
    final decoded = jsonDecode(utf8.decode(payloadBytes));
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  List<int> _decodeBase64Url(String input) {
    final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(normalized.padRight((normalized.length + 3) ~/ 4 * 4, '='));
  }
}
