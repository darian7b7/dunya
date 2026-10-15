// What the player has learned and their records, stored on the device.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/learning.dart';
import 'core/world.dart';

class AppState extends ChangeNotifier {
  AppState(this.world, this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en' ? 'en' : 'de';
      return;
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    lang = j['lang'] as String? ?? 'de';
    bestFlags = j['bestFlags'] as int? ?? 0;
    bestStreak = j['bestStreak'] as int? ?? 0;
    for (final e in (j['progress'] as Map? ?? {}).entries) {
      if (world.byIso(e.key as String) != null) _progress[e.key as String] = Progress.values.byName(e.value as String);
    }
  }

  static const _key = 'dunya.v1';
  final World world;
  final SharedPreferences _prefs;

  String lang = 'de';
  int bestFlags = 0;
  int bestStreak = 0;
  final _progress = <String, Progress>{};

  Progress progressOf(String iso) => _progress[iso] ?? Progress.none;
  int get countriesKnown => _progress.values.where((p) => p != Progress.none).length;
  int get countriesComplete => _progress.values.where((p) => p == Progress.complete).length;

  /// Only moves forward: a correct answer never turns a country grey again.
  void advance(String iso, Progress p) {
    if (p.index <= progressOf(iso).index) return;
    _progress[iso] = p;
    _save();
  }

  void resetProgress() {
    _progress.clear();
    _save();
  }

  void setLang(String value) {
    lang = value;
    _save();
  }

  /// Returns true for a new record.
  bool recordFlags(int score) => _record(score > bestFlags, () => bestFlags = score);
  bool recordStreak(int streak) => _record(streak > bestStreak, () => bestStreak = streak);

  bool _record(bool better, void Function() set) {
    if (!better) return false;
    set();
    _save();
    return true;
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'lang': lang,
        'bestFlags': bestFlags,
        'bestStreak': bestStreak,
        'progress': {for (final e in _progress.entries) e.key: e.value.name},
      }),
    );
    notifyListeners();
  }
}
