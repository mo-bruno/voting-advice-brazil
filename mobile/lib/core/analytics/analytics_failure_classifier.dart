import 'dart:async';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'analytics_dimensions.dart';

AnalyticsFailureType classifyAnalyticsFailure(
  Object error, {
  bool moderationWrite = false,
}) {
  if (error is TimeoutException) return AnalyticsFailureType.timeout;
  if (error is http.ClientException) return AnalyticsFailureType.network;
  if (error is ApiException) {
    final status = error.statusCode;
    if (status == 408) return AnalyticsFailureType.timeout;
    if (status == 422 && moderationWrite) {
      return AnalyticsFailureType.moderationRejected;
    }
    if (status == 429) return AnalyticsFailureType.rateLimited;
    if (status == 503) return AnalyticsFailureType.unavailable;
    if (status != null && status >= 500) {
      return AnalyticsFailureType.server;
    }
    if (status != null && status >= 400) {
      return AnalyticsFailureType.client;
    }
  }
  return AnalyticsFailureType.unknown;
}
