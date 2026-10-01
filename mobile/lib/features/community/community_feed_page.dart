import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_navigation.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import 'community_session.dart';
import 'create_post_page.dart';
import 'models/community_models.dart';
import 'models/community_theme.dart';
import 'post_detail_page.dart';
import 'utils/community_errors.dart';
import 'widgets/community_actions.dart';
import 'widgets/post_card.dart';

enum _SortMode {
  votados('score'),
  recentes('recent');

  const _SortMode(this.apiValue);
  final String apiValue;
}

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key, this.apiClient, this.analytics});
  final ApiClient? apiClient;
  final AnalyticsService? analytics;

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final _session = CommunitySession();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  final _scrollController = ScrollController();
  final Set<String> _voting = {};
  final Set<String> _acting = {};
  bool _loading = true;
  bool _failed = false;
  bool _loadMoreFailed = false;
  bool _loadingThemes = false;
  String? _anonymousId;
  String? _themeSlug;
  String? _themeName;
  List<CommunityTheme>? _themes;
  _SortMode _sort = _SortMode.votados;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  Future<T> _runWrite<T>({
    required AnalyticsOperation operation,
    required Future<T> Function() action,
  }) async {
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    try {
      final result = await action();
      outcome = AnalyticsOutcome.success;
      return result;
    } catch (error) {
      failureType = classifyAnalyticsFailure(error);
      rethrow;
    } finally {
      stopwatch.stop();
      _track(attemptAnalytics.operationResult(
        operation: operation,
        outcome: outcome,
        trigger: AnalyticsTrigger.submit,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
      ));
    }
  }

  Future<void> _init({
    AnalyticsTrigger trigger = AnalyticsTrigger.initial,
  }) async {
    try {
      final id = await DeviceIdentityStore().getOrCreateDeviceId();
      if (!mounted) return;
      _anonymousId = id;
      await _loadPage(1, trigger: trigger);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 200 &&
        _session.hasMore &&
        !_loadMoreFailed &&
        !_loading) {
      unawaited(_loadPage(
        _session.currentPage + 1,
        trigger: AnalyticsTrigger.pagination,
      ));
    }
  }

  Future<void> _loadPage(
    int page, {
    required AnalyticsTrigger trigger,
  }) async {
    if (!mounted || _anonymousId == null || (page > 1 && _loading)) return;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    if (page == 1) _generation++;
    final generation = _generation;
    final revisions = _session.postRevisions;
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? itemCount;
    setState(() {
      _loading = true;
      _failed = false;
      _loadMoreFailed = false;
    });
    try {
      final data = await _api.listPosts(
        anonymousId: _anonymousId!,
        page: page,
        sort: _sort.apiValue,
        themeSlug: _themeSlug,
      );
      if (!mounted || generation != _generation) {
        outcome = AnalyticsOutcome.stale;
        return;
      }
      final current = {for (final post in _session.feed) post.id: post};
      final latestRevisions = _session.postRevisions;
      final posts = (data['posts'] as List)
          .map((p) => PostSummary.fromJson(p as Map<String, dynamic>))
          .map((post) => latestRevisions[post.id] != revisions[post.id]
              ? _session.updatedPost(post.id) ?? current[post.id] ?? post
              : post)
          .toList();
      itemCount = posts.length;
      outcome =
          posts.isEmpty ? AnalyticsOutcome.empty : AnalyticsOutcome.success;
      final hasMore = data['has_next'] as bool && posts.isNotEmpty;
      if (page == 1) {
        _session.setFeed(posts, hasMore: hasMore, page: page);
      } else {
        _session.appendFeed(posts, hasMore: hasMore, page: page);
      }
    } catch (error) {
      if (!mounted || generation != _generation) {
        outcome = AnalyticsOutcome.stale;
        failureType = null;
        itemCount = null;
        return;
      }
      failureType = classifyAnalyticsFailure(error);
      if (page == 1) {
        _failed = true;
      } else {
        _loadMoreFailed = true;
        _notice('Não foi possível carregar mais posts.');
      }
    } finally {
      stopwatch.stop();
      if (generation != _generation) {
        outcome = AnalyticsOutcome.stale;
        failureType = null;
        itemCount = null;
      }
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.communityFeedLoad,
        outcome: outcome,
        trigger: trigger,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: itemCount,
      ));
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _vote(String postId, int value) async {
    if (_anonymousId == null || _voting.contains(postId)) return;
    setState(() => _voting.add(postId));
    try {
      final updated = await _runWrite(
        operation: AnalyticsOperation.communityVote,
        action: () async => PostSummary.fromJson(
          await _api.votePost(
            postId,
            value,
            anonymousId: _anonymousId!,
          ),
        ),
      );
      if (!mounted) return;
      _session.updatePost(updated);
    } catch (error) {
      _notice(communityErrorMessage(error,
          fallback: 'Não foi possível registrar seu voto.'));
      if (error is ApiException && error.statusCode == 410) {
        await _loadPage(1, trigger: AnalyticsTrigger.refresh);
      }
    } finally {
      if (mounted) setState(() => _voting.remove(postId));
    }
  }

  Future<void> _reportPost(String postId) async {
    if (_anonymousId == null || _acting.contains(postId)) return;
    _acting.add(postId);
    try {
      final reason = await chooseReportReason(context);
      if (reason == null || !mounted) return;
      await _runWrite(
        operation: AnalyticsOperation.communityReport,
        action: () => _api.reportPost(
          postId,
          reason: reason,
          anonymousId: _anonymousId!,
        ),
      );
      _notice('Denúncia registrada. Obrigado.');
      await _loadPage(1, trigger: AnalyticsTrigger.refresh);
    } catch (error) {
      _notice(communityErrorMessage(error,
          fallback: 'Não foi possível enviar a denúncia.'));
    } finally {
      _acting.remove(postId);
    }
  }

  Future<void> _deletePost(String postId) async {
    if (_anonymousId == null || _acting.contains(postId)) return;
    _acting.add(postId);
    try {
      if (!await confirmCommunityRemoval(context, comment: false) || !mounted) {
        return;
      }
      await _api.deletePost(postId, anonymousId: _anonymousId!);
      _notice('Post removido.');
      await _loadPage(1, trigger: AnalyticsTrigger.refresh);
    } catch (error) {
      _notice(communityErrorMessage(error,
          fallback: 'Não foi possível apagar o post.'));
    } finally {
      _acting.remove(postId);
    }
  }

  Future<void> _openDetail(PostSummary post) async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: communityPostRoute),
          builder: (_) => PostDetailPage(
            postId: post.id,
            apiClient: _api,
            analytics: _analytics,
          ),
        ));
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final created = await Navigator.push<PostSummary>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: communityCreateRoute),
          builder: (_) => CreatePostPage(
            apiClient: _api,
            initialThemeSlug: _themeSlug,
            analytics: _analytics,
          ),
        ));
    if (!mounted || created == null) return;
    _session.invalidate();
    setState(() {
      _sort = _SortMode.recentes;
      _themeSlug = null;
      _themeName = null;
    });
    unawaited(_loadPage(1, trigger: AnalyticsTrigger.refresh));
    _notice('Publicação aprovada e enviada.');
    await _openDetail(created);
  }

  void _changeSort(_SortMode mode) {
    if (_sort == mode) return;
    _session.invalidate();
    setState(() => _sort = mode);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(_loadPage(1, trigger: AnalyticsTrigger.refresh));
  }

  Future<void> _chooseTheme() async {
    if (_loadingThemes) return;
    setState(() => _loadingThemes = true);
    try {
      _themes ??= await _api.fetchThemes();
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            children: [
              const Padding(
                  padding: EdgeInsets.all(16), child: Text('FILTRAR POR TEMA')),
              ListTile(
                  title: const Text('Todos os temas'),
                  selected: _themeSlug == null,
                  onTap: () => Navigator.pop(context, '')),
              for (final theme in _themes!)
                ListTile(
                    title: Text(theme.nome),
                    selected: _themeSlug == theme.slug,
                    onTap: () => Navigator.pop(context, theme.slug)),
            ],
          ),
        )),
      );
      if (!mounted || selected == null) return;
      _session.invalidate();
      setState(() {
        _themeSlug = selected.isEmpty ? null : selected;
        _themeName = selected.isEmpty
            ? null
            : _themes!.firstWhere((t) => t.slug == selected).nome;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      await _loadPage(1, trigger: AnalyticsTrigger.refresh);
    } catch (_) {
      _notice('Não foi possível carregar os temas. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loadingThemes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return AppScaffold(
      title: 'FÓRUM POLÍTICO',
      subtitle: 'discussão sob aliases pseudônimos',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SortTab(
                    label: 'MAIS VOTADOS',
                    selected: _sort == _SortMode.votados,
                    onTap: () => _changeSort(_SortMode.votados)),
                _SortTab(
                    label: 'RECENTES',
                    selected: _sort == _SortMode.recentes,
                    onTap: () => _changeSort(_SortMode.recentes)),
                IconButton(
                    tooltip: 'Filtrar por tema',
                    onPressed: _loadingThemes ? null : _chooseTheme,
                    icon: Icon(_themeSlug == null
                        ? Icons.filter_list
                        : Icons.filter_list_alt)),
              ]),
        ),
        if (_themeName != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Tema: $_themeName')),
        const Divider(height: 1),
        if (_loading && feed.isNotEmpty) const LinearProgressIndicator(),
        if (_failed && feed.isNotEmpty)
          TextButton(
              onPressed: () => _loadPage(
                    1,
                    trigger: AnalyticsTrigger.retry,
                  ),
              child: const Text('Não foi possível atualizar. TENTAR DE NOVO')),
        Expanded(
            child: _loading && feed.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _failed && feed.isEmpty
                    ? _FeedMessage(
                        title: 'Não foi possível carregar o fórum',
                        body: 'Verifique sua conexão e tente novamente.',
                        action: OutlinedButton(
                            onPressed: () => _init(
                                  trigger: AnalyticsTrigger.retry,
                                ),
                            child: const Text('TENTAR DE NOVO')),
                      )
                    : feed.isEmpty
                        ? _FeedMessage(
                            title: 'Nenhum post por aqui ainda',
                            body: _themeSlug == null
                                ? 'Seja o primeiro a começar uma discussão.'
                                : 'Nenhuma publicação neste tema. Escolha outro tema ou comece uma discussão.')
                        : RefreshIndicator(
                            onRefresh: () => _loadPage(
                              1,
                              trigger: AnalyticsTrigger.refresh,
                            ),
                            child: ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount:
                                  feed.length + (_session.hasMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                if (index == feed.length) {
                                  return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: _loading
                                            ? const CircularProgressIndicator()
                                            : OutlinedButton(
                                                onPressed: () => _loadPage(
                                                      _session.currentPage + 1,
                                                      trigger: AnalyticsTrigger
                                                          .pagination,
                                                    ),
                                                child: const Text(
                                                    'CARREGAR MAIS')),
                                      ));
                                }
                                final post = feed[index];
                                return PostCard(
                                    post: post,
                                    votePending: _voting.contains(post.id),
                                    onReport: () => _reportPost(post.id),
                                    onDelete: () => _deletePost(post.id),
                                    onTap: () => _openDetail(post),
                                    onVote: (value) => _vote(post.id, value));
                              },
                            ),
                          )),
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _create,
                    child: const Row(children: [
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('ESCREVER UM POST',
                              textAlign: TextAlign.center)),
                    ]),
                  )),
            )),
      ]),
    );
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              foregroundColor:
                  selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
              minimumSize: const Size(48, 48),
              side:
                  selected ? const BorderSide(color: AppTheme.outline) : null),
          child: Text(label),
        ),
      );
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({required this.title, required this.body, this.action});
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forum_outlined, size: 40),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ));
}
