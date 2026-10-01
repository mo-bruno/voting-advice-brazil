import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/news_article.dart';

enum NewsStatus { idle, loading, ready, empty, error }

/// Estado da lista de notícias da home.
///
/// Segue o mesmo padrão das outras sessions do app: singleton com
/// `ChangeNotifier` e um construtor `testOnly` para injetar o cliente.
class NewsSession extends ChangeNotifier {
  NewsSession._({ApiClient? api, AnalyticsService? analytics})
      : api = api ?? ApiClient(),
        _analytics = analytics ?? AnalyticsService();

  factory NewsSession({
    ApiClient? api,
    AnalyticsService? analytics,
  }) =>
      NewsSession._(api: api, analytics: analytics);

  @visibleForTesting
  factory NewsSession.testOnly({
    ApiClient? api,
    AnalyticsService? analytics,
  }) =>
      NewsSession._(api: api, analytics: analytics);

  static final NewsSession instance = NewsSession();

  final ApiClient api;
  final AnalyticsService _analytics;
  int _loadGeneration = 0;

  NewsStatus status = NewsStatus.idle;
  List<NewsArticle> articles = [];
  String periodLabel = '';

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  Future<void> load({
    AnalyticsTrigger trigger = AnalyticsTrigger.initial,
  }) async {
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final generation = ++_loadGeneration;
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? itemCount;
    status = NewsStatus.loading;
    notifyListeners();

    try {
      final result = await api.fetchWeeklyNews();
      if (generation != _loadGeneration) {
        outcome = AnalyticsOutcome.stale;
        return;
      }
      articles = result.articles;
      periodLabel = result.periodLabel;
      status = articles.isEmpty ? NewsStatus.empty : NewsStatus.ready;
      itemCount = articles.length > 1000 ? 1000 : articles.length;
      outcome =
          articles.isEmpty ? AnalyticsOutcome.empty : AnalyticsOutcome.success;
    } catch (error) {
      if (generation != _loadGeneration) {
        outcome = AnalyticsOutcome.stale;
        return;
      }
      articles = [];
      status = NewsStatus.error;
      failureType = classifyAnalyticsFailure(error);
    } finally {
      stopwatch.stop();
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.newsLoad,
        outcome: outcome,
        trigger: trigger,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: itemCount,
      ));
      if (generation == _loadGeneration) notifyListeners();
    }
  }
}
