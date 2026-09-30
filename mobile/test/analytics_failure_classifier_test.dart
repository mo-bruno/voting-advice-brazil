import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_dimensions.dart';
import 'package:guia_eleitoral/core/analytics/analytics_failure_classifier.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

void main() {
  test('classifies generic transport and HTTP failure families', () {
    expect(
      classifyAnalyticsFailure(TimeoutException('private timeout detail')),
      AnalyticsFailureType.timeout,
    );
    expect(
      classifyAnalyticsFailure(
        const ApiException('private moderation detail', statusCode: 422),
        moderationWrite: true,
      ),
      AnalyticsFailureType.moderationRejected,
    );
    expect(
      classifyAnalyticsFailure(
        const ApiException('private rate detail', statusCode: 429),
      ),
      AnalyticsFailureType.rateLimited,
    );
    expect(
      classifyAnalyticsFailure(
        const ApiException('private outage detail', statusCode: 503),
      ),
      AnalyticsFailureType.unavailable,
    );
    expect(
      classifyAnalyticsFailure(http.ClientException('private network detail')),
      AnalyticsFailureType.network,
    );
  });

  test('classifies remaining status groups without exposing error text', () {
    expect(
      classifyAnalyticsFailure(
        const ApiException('private client detail', statusCode: 404),
      ),
      AnalyticsFailureType.client,
    );
    expect(
      classifyAnalyticsFailure(
        const ApiException('private server detail', statusCode: 500),
      ),
      AnalyticsFailureType.server,
    );
    expect(
      classifyAnalyticsFailure(StateError('private unknown detail')),
      AnalyticsFailureType.unknown,
    );
  });
}
