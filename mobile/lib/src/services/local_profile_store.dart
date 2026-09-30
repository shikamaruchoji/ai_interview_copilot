import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// PIN-derived profile folder + encrypted prefs for API keys.
class LocalProfileStore {
  LocalProfileStore({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kSaltKey = 'aic_profile_salt_v1';
  static const _kGeminiKey = 'gemini_api_key';
  static const _kLegacyOpenAiKey = 'openai_api_key';

  final FlutterSecureStorage _secure;

  Future<String> _deviceSalt() async {
    var s = await _secure.read(key: _kSaltKey);
    if (s == null || s.isEmpty) {
      final rnd = List<int>.generate(16, (i) => DateTime.now().microsecondsSinceEpoch.hashCode & 0xff);
      s = base64UrlEncode(rnd);
      await _secure.write(key: _kSaltKey, value: s);
    }
    return s;
  }

  Future<String> profileIdForPin(String pin) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      throw ArgumentError('PIN must be 4 digits');
    }
    final salt = await _deviceSalt();
    final bytes = utf8.encode('aicopilot:v1:$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<Directory> profileDir(String profileId) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'profiles', profileId));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> saveResumeText(String profileId, String text) async {
    final dir = await profileDir(profileId);
    File(p.join(dir.path, 'resume.txt')).writeAsStringSync(text.trim(), flush: true);
  }

  Future<void> saveJobText(String profileId, String text) async {
    final dir = await profileDir(profileId);
    File(p.join(dir.path, 'job.txt')).writeAsStringSync(text.trim(), flush: true);
  }

  Future<String?> readResumeText(String profileId) async {
    final dir = await profileDir(profileId);
    final f = File(p.join(dir.path, 'resume.txt'));
    if (!f.existsSync()) return null;
    return f.readAsStringSync();
  }

  Future<String?> readJobText(String profileId) async {
    final dir = await profileDir(profileId);
    final f = File(p.join(dir.path, 'job.txt'));
    if (!f.existsSync()) return null;
    return f.readAsStringSync();
  }

  Future<SetupFlags> setupFlags(String profileId) async {
    final resume = (await readResumeText(profileId))?.trim() ?? '';
    final job = (await readJobText(profileId))?.trim() ?? '';
    return SetupFlags(
      hasResume: resume.isNotEmpty,
      hasJob: job.isNotEmpty,
    );
  }

  Future<void> setGeminiApiKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      await _secure.delete(key: _kGeminiKey);
      return;
    }
    await _secure.write(key: _kGeminiKey, value: key.trim());
  }

  /// Prefer Gemini key; if missing, reuse legacy OpenAI slot so older installs still have a key until user saves again.
  Future<String?> geminiApiKey() async {
    final g = await _secure.read(key: _kGeminiKey);
    if (g != null && g.isNotEmpty) return g;
    return _secure.read(key: _kLegacyOpenAiKey);
  }
}

class SetupFlags {
  final bool hasResume;
  final bool hasJob;

  SetupFlags({
    required this.hasResume,
    required this.hasJob,
  });
}
