import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/news_article.dart';

enum NewsStatus { idle, loading, ready, empty, error }

/// Estado da lista de notícias da home.
///
/// Segue o mesmo padrão das outras sessions do app: singleton com
/// `ChangeNotifier` e um construtor `testOnly` para injetar o cliente.
class NewsSession extends ChangeNotifier {
  NewsSession._({ApiClient? api}) : api = api ?? ApiClient();

  @visibleForTesting
  factory NewsSession.testOnly({ApiClient? api}) => NewsSession._(api: api);

  static final NewsSession instance = NewsSession._();

  final ApiClient api;

  NewsStatus status = NewsStatus.idle;
  List<NewsArticle> articles = [];
  String periodLabel = '';

  Future<void> load() async {
    status = NewsStatus.loading;
    notifyListeners();

    try {
      final result = await api.fetchWeeklyNews();
      articles = result.articles;
      periodLabel = result.periodLabel;
      status = articles.isEmpty ? NewsStatus.empty : NewsStatus.ready;
    } catch (_) {
      articles = [];
      status = NewsStatus.error;
    }
    notifyListeners();
  }
}
