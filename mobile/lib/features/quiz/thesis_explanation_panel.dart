import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/link/link_opener.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/thesis_explanation.dart';

class ThesisExplanationPanel extends StatefulWidget {
  final ThesisExplanation explanation;
  final LinkOpener linkOpener;
  final AnalyticsService? analytics;

  const ThesisExplanationPanel({
    super.key,
    required this.explanation,
    this.linkOpener = openExternalLink,
    this.analytics,
  });

  @override
  State<ThesisExplanationPanel> createState() => _ThesisExplanationPanelState();
}

class _ThesisExplanationPanelState extends State<ThesisExplanationPanel> {
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  bool _expanded = false;
  bool _hasTrackedExpansion = false;

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded && !_hasTrackedExpansion) {
      _hasTrackedExpansion = true;
      _track(_analytics.engagementAction(
        action: AnalyticsAction.evidenceOpen,
        surface: AnalyticsSurface.quiz,
      ));
    }
  }

  Future<void> _openSource(ExplanationSource source) async {
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    var opened = false;
    try {
      opened = await widget.linkOpener(source.url);
    } catch (_) {
      // The question and its explanation remain available if a link fails.
    }
    _track(attemptAnalytics.engagementAction(
      action: AnalyticsAction.outboundOpen,
      surface: AnalyticsSurface.quiz,
      target: AnalyticsTarget.quizSource,
      outcome: opened ? AnalyticsOutcome.success : AnalyticsOutcome.failed,
    ));
    if (opened) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Não foi possível abrir a fonte. Tente novamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Semantics(
              expanded: _expanded,
              child: TextButton(
                onPressed: _toggleExpanded,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 64),
                  padding: const EdgeInsets.all(16),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 22, color: AppTheme.onSurface),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entenda esta pergunta',
                              style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            _expanded
                                ? 'Toque para recolher'
                                : 'Explicação em linguagem simples',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.onSurface),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: AppTheme.outlineVariant, height: 1),
                  for (final paragraph in widget.explanation.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(paragraph,
                          style: textTheme.bodyLarge?.copyWith(height: 1.5)),
                    ),
                  const SizedBox(height: 20),
                  Text('Fontes para consultar', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  for (final source in widget.explanation.sources)
                    TextButton(
                      onPressed: () => _openSource(source),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.centerLeft,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              source.title,
                              style: textTheme.bodyMedium?.copyWith(
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.open_in_new, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
