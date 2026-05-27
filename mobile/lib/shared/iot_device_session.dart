import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/device/device_identity_store.dart';
import 'models/iot_device.dart';

class IotDeviceSession extends ChangeNotifier {
  IotDeviceSession._({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  })  : api = api ?? ApiClient(),
        deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  @visibleForTesting
  factory IotDeviceSession.testOnly({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  }) =>
      IotDeviceSession._(
        api: api,
        deviceIdentityStore: deviceIdentityStore,
      );

  static final IotDeviceSession instance = IotDeviceSession._();

  final ApiClient api;
  final DeviceIdentityStore deviceIdentityStore;
  IotDevice? device;
  bool loading = false;
  String? error;

  Future<void> loadStatus() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      device = await api.fetchIotDevice(anonymousId: anonymousId);
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> pairWithPayload(IotPairingPayload payload) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      device = await api.pairIotDevice(
        anonymousId: anonymousId,
        deviceToken: payload.deviceToken,
        pairingCode: payload.pairingCode,
      );
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> pairWithManualCode(IotManualPairingInput input) async {
    if (!input.isValid) {
      error = 'Informe o codigo de 6 digitos e o ID curto de 8 caracteres.';
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      device = await api.pairIotDevice(
        anonymousId: anonymousId,
        deviceTokenPrefix: input.normalizedShortId,
        pairingCode: input.normalizedPairingCode,
      );
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> sendQuizPulse({
    required String answer,
    required int current,
    required int total,
  }) async {
    if (device == null) return;
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      // Fire-and-forget
      unawaited(
        api.sendQuizPulse(
          anonymousId: anonymousId,
          answer: answer,
          current: current,
          total: total,
        ),
      );
    } catch (_) {
      // Ignora erros, é fire-and-forget
    }
  }

  Future<void> unlink() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      await api.deleteIotDevice(anonymousId: anonymousId);
      device = null;
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
