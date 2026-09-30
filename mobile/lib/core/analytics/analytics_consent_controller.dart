import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnalyticsConsent { pending, granted, denied }

abstract interface class AnalyticsConsentStore {
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class AnalyticsConsentEffects {
  Future<void> updateConsent({required bool granted});
}

class SharedPreferencesAnalyticsConsentStore implements AnalyticsConsentStore {
  static const key = 'farol_politico_analytics_consent_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, value);
    if (!saved) throw StateError('analytics consent was not persisted');
  }
}

class AnalyticsConsentController extends ChangeNotifier {
  AnalyticsConsentController({
    required AnalyticsConsentStore store,
    required AnalyticsConsentEffects effects,
    void Function(Object error)? onError,
  })  : _store = store,
        _effects = effects,
        _onError = onError;

  @visibleForTesting
  factory AnalyticsConsentController.testOnly({
    required AnalyticsConsentStore store,
    required AnalyticsConsentEffects effects,
    void Function(Object error)? onError,
  }) = AnalyticsConsentController;

  final AnalyticsConsentStore _store;
  final AnalyticsConsentEffects _effects;
  final void Function(Object error)? _onError;
  Future<void> _writeTail = Future<void>.value();
  int _revision = 0;
  AnalyticsConsent _state = AnalyticsConsent.pending;
  bool _denialPersistenceFailed = false;

  AnalyticsConsent get state => _state;
  bool get isGranted => _state == AnalyticsConsent.granted;
  bool get denialPersistenceFailed => _denialPersistenceFailed;
  int get revision => _revision;

  Future<void> hydrate() async {
    final revision = ++_revision;
    try {
      final stored = await _store.read();
      if (revision != _revision) return;
      if (stored == 'granted') {
        final applied = await _applyEffect(true);
        if (applied && revision == _revision) {
          _setState(AnalyticsConsent.granted);
        }
      } else if (stored == 'denied') {
        _setState(AnalyticsConsent.denied);
        await _applyEffect(false);
      }
      if (revision == _revision) {
        _setDenialPersistenceFailed(false);
      }
    } catch (error) {
      _report(error);
    }
  }

  Future<bool> grant() async {
    final revision = ++_revision;
    final persisted = await _persist('granted');
    if (!persisted) return false;
    if (revision == _revision) {
      final applied = await _applyEffect(true);
      if (applied && revision == _revision) {
        _setDenialPersistenceFailed(false);
        _setState(AnalyticsConsent.granted);
      }
    }
    return true;
  }

  Future<bool> deny() async {
    final revision = ++_revision;
    _setState(AnalyticsConsent.denied);
    final effect = _applyEffect(false);
    final persisted = await _persist('denied');
    await effect;
    if (revision == _revision) {
      _setDenialPersistenceFailed(!persisted);
    }
    return persisted;
  }

  Future<bool> _persist(String value) async {
    final write = _writeTail.then((_) => _store.write(value));
    _writeTail = write.then<void>((_) {}, onError: (Object error) {});
    try {
      await write;
      return true;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<bool> _applyEffect(bool granted) async {
    try {
      await _effects.updateConsent(granted: granted);
      return true;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  void _setState(AnalyticsConsent value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  void _setDenialPersistenceFailed(bool value) {
    if (_denialPersistenceFailed == value) return;
    _denialPersistenceFailed = value;
    notifyListeners();
  }

  void _report(Object error) {
    _onError?.call(error);
  }
}
