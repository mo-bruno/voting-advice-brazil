import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import 'community_session.dart';
import 'models/community_models.dart';
import 'utils/community_errors.dart';
import 'widgets/comment_input.dart';
import 'widgets/comment_tile.dart';
import 'widgets/community_actions.dart';
import 'widgets/post_card.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.postId,
    this.apiClient,
    this.analytics,
  });
  final String postId;
  final ApiClient? apiClient;
  final AnalyticsService? analytics;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _acting = {};
  PostDetail? _detail;
  String? _anonymousId;
  String? _loadError;
  String? _commentError;
  bool _loading = true;
  bool _refreshing = false;
  bool _sendingComment = false;
  bool _voting = false;
  bool _allowPop = false;
  bool _confirmingExit = false;
  int _loadGeneration = 0;
  int _mutationVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  Future<T> _runWrite<T>({
    required AnalyticsOperation operation,
    required bool moderationWrite,
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
      failureType = classifyAnalyticsFailure(
        error,
        moderationWrite: moderationWrite,
      );
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

  Future<void> _load({
    AnalyticsTrigger trigger = AnalyticsTrigger.initial,
  }) async {
    if (!mounted) return;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final generation = ++_loadGeneration;
    final version = _mutationVersion;
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? itemCount;
    setState(() {
      _loading = _detail == null;
      _refreshing = _detail != null;
      _loadError = null;
    });
    try {
      _anonymousId ??= await DeviceIdentityStore().getOrCreateDeviceId();
      final data =
          await _api.getPost(widget.postId, anonymousId: _anonymousId!);
      if (!mounted ||
          generation != _loadGeneration ||
          version != _mutationVersion) {
        outcome = AnalyticsOutcome.stale;
        return;
      }
      final detail = PostDetail.fromJson(data);
      itemCount = detail.comments.length;
      outcome = AnalyticsOutcome.success;
      _detail = detail;
      CommunitySession().updatePost(_detail!.post);
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          version != _mutationVersion) {
        outcome = AnalyticsOutcome.stale;
        failureType = null;
        itemCount = null;
        return;
      }
      failureType = classifyAnalyticsFailure(error);
      _loadError = error is ApiException && error.statusCode == 404
          ? 'Esta discussão não foi encontrada.'
          : 'Não foi possível carregar a discussão. Verifique sua conexão e tente novamente.';
    } finally {
      stopwatch.stop();
      if (generation != _loadGeneration || version != _mutationVersion) {
        outcome = AnalyticsOutcome.stale;
        failureType = null;
        itemCount = null;
      }
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.communityPostLoad,
        outcome: outcome,
        trigger: trigger,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: itemCount,
      ));
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _vote(int value) async {
    if (_detail == null ||
        _detail!.post.removed ||
        _voting ||
        _anonymousId == null) {
      return;
    }
    setState(() => _voting = true);
    try {
      final vote = await _runWrite(
        operation: AnalyticsOperation.communityVote,
        moderationWrite: false,
        action: () async => PostSummary.fromJson(
          await _api.votePost(
            widget.postId,
            value,
            anonymousId: _anonymousId!,
          ),
        ),
      );
      if (!mounted) return;
      final current = _detail!;
      final updated = vote.copyWith(commentCount: current.comments.length);
      _mutationVersion++;
      setState(() =>
          _detail = PostDetail(post: updated, comments: current.comments));
      CommunitySession().updatePost(updated);
    } catch (error) {
      _notice(communityErrorMessage(error,
          fallback: 'Não foi possível registrar seu voto.'));
      if (error is ApiException && error.statusCode == 410) {
        unawaited(_load(trigger: AnalyticsTrigger.refresh));
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty ||
        content.runes.length > 300 ||
        _detail == null ||
        _detail!.post.removed ||
        _sendingComment ||
        _anonymousId == null) {
      return;
    }
    setState(() {
      _sendingComment = true;
      _commentError = null;
    });
    try {
      final created = await _runWrite(
        operation: AnalyticsOperation.communityCommentCreate,
        moderationWrite: true,
        action: () async => PostComment.fromJson(
          await _api.createComment(
            widget.postId,
            content,
            anonymousId: _anonymousId!,
          ),
        ),
      );
      if (!mounted) return;
      final current = _detail!;
      final comments =
          current.comments.any((comment) => comment.id == created.id)
              ? current.comments
              : [...current.comments, created];
      final updated = current.post.copyWith(commentCount: comments.length);
      _mutationVersion++;
      _commentController.clear();
      setState(() => _detail = PostDetail(post: updated, comments: comments));
      CommunitySession().updatePost(updated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _commentError = communityErrorMessage(error,
          fallback:
              'Não foi possível enviar seu comentário. Verifique sua conexão e tente novamente.'));
      if (error is ApiException && error.statusCode == 410) {
        unawaited(_load(trigger: AnalyticsTrigger.refresh));
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _act({PostComment? comment, required bool report}) async {
    final key = comment?.id ?? widget.postId;
    if (_anonymousId == null || _acting.contains(key)) return;
    _acting.add(key);
    try {
      if (report) {
        final reason = await chooseReportReason(context);
        if (reason == null || !mounted) return;
        if (comment == null) {
          await _runWrite(
            operation: AnalyticsOperation.communityReport,
            moderationWrite: false,
            action: () => _api.reportPost(
              widget.postId,
              reason: reason,
              anonymousId: _anonymousId!,
            ),
          );
        } else {
          await _runWrite(
            operation: AnalyticsOperation.communityReport,
            moderationWrite: false,
            action: () => _api.reportComment(
              widget.postId,
              comment.id,
              reason: reason,
              anonymousId: _anonymousId!,
            ),
          );
        }
        _notice('Denúncia registrada. Obrigado.');
      } else {
        if (!await confirmCommunityRemoval(context, comment: comment != null) ||
            !mounted) {
          return;
        }
        if (comment == null) {
          await _api.deletePost(widget.postId, anonymousId: _anonymousId!);
        } else {
          await _api.deleteComment(widget.postId, comment.id,
              anonymousId: _anonymousId!);
        }
        _notice(comment == null ? 'Post removido.' : 'Comentário removido.');
      }
      await _load(trigger: AnalyticsTrigger.refresh);
    } catch (error) {
      _notice(communityErrorMessage(error,
          fallback: report
              ? 'Não foi possível enviar a denúncia.'
              : 'Não foi possível apagar o conteúdo.'));
    } finally {
      _acting.remove(key);
    }
  }

  Future<void> _requestExit() async {
    if (_confirmingExit || !mounted) return;
    if (_sendingComment) {
      _notice('Aguarde a verificação do comentário antes de sair.');
      return;
    }
    if (_commentController.text.trim().isNotEmpty) {
      _confirmingExit = true;
      FocusScope.of(context).unfocus();
      final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Descartar comentário?'),
                content: const Text('O texto ainda não foi enviado.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CONTINUAR ESCREVENDO')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('DESCARTAR')),
                ],
              ));
      _confirmingExit = false;
      if (!mounted || discard != true) return;
    }
    setState(() => _allowPop = true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final comments = detail?.comments ?? [];
    return PopScope(
      canPop: _allowPop ||
          (!_sendingComment && _commentController.text.trim().isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: AppScaffold(
        title:
            '${comments.length} COMENTÁRIO${comments.length == 1 ? '' : 'S'}',
        leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            onPressed: _requestExit),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : detail == null
                ? Center(
                    child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          _loadError ??
                              'Não foi possível carregar a discussão.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: () => _load(
                                trigger: AnalyticsTrigger.retry,
                              ),
                          child: const Text('TENTAR DE NOVO')),
                    ]),
                  ))
                : LayoutBuilder(
                    builder: (context, constraints) => Column(children: [
                          if (_refreshing) const LinearProgressIndicator(),
                          if (_loadError != null)
                            TextButton(
                                onPressed: () => _load(
                                      trigger: AnalyticsTrigger.retry,
                                    ),
                                child: const Text(
                                    'Não foi possível atualizar. TENTAR DE NOVO')),
                          Expanded(
                              child: RefreshIndicator(
                            onRefresh: () => _load(
                              trigger: AnalyticsTrigger.refresh,
                            ),
                            child: ListView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                PostCard(
                                    post: detail.post,
                                    detailed: true,
                                    onTap: () {},
                                    votePending: _voting,
                                    onVote: _vote,
                                    onDelete: () => _act(report: false),
                                    onReport: () => _act(report: true)),
                                const Divider(height: 1),
                                if (comments.isEmpty)
                                  const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                          'Nenhum comentário ainda. Comece a discussão.')),
                                for (final comment in comments)
                                  CommentTile(
                                      key: ValueKey(comment.id),
                                      comment: comment,
                                      onDelete: () =>
                                          _act(comment: comment, report: false),
                                      onReport: () =>
                                          _act(comment: comment, report: true)),
                                const SizedBox(height: 16),
                              ],
                            ),
                          )),
                          if (!detail.post.removed)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight * .65),
                              child: SingleChildScrollView(
                                  child: CommentInput(
                                controller: _commentController,
                                sending: _sendingComment,
                                error: _commentError,
                                onSend: _addComment,
                                onChanged: () =>
                                    setState(() => _commentError = null),
                              )),
                            ),
                        ])),
      ),
    );
  }
}
