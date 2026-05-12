import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/official_evidence.dart';
import '../../shared/models/political_actor.dart';
import '../../shared/political_actor_session.dart';

class PoliticalActorProfilePage extends StatefulWidget {
  final PoliticalActorSession? session;

  const PoliticalActorProfilePage({super.key, this.session});

  @override
  State<PoliticalActorProfilePage> createState() =>
      _PoliticalActorProfilePageState();
}

class _PoliticalActorProfilePageState extends State<PoliticalActorProfilePage> {
  late final _session = widget.session ?? PoliticalActorSession.instance;
  bool _loading = true;
  String? _error;
  int? _loadedActorId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actor = ModalRoute.of(context)!.settings.arguments! as PoliticalActor;
    if (_loadedActorId == actor.id) return;
    _loadedActorId = actor.id;
    _session.evidence = [];
    _session.cacheStatus = null;
    unawaited(_loadEvidence(actor.id));
  }

  Future<void> _loadEvidence(int actorId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _fetchEvidenceWithRetry(actorId);
      _session.evidence = response.evidence;
      _session.cacheStatus = response.cacheStatus;
    } catch (error) {
      _error = _friendlyEvidenceError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<EvidenceResponse> _fetchEvidenceWithRetry(int actorId) async {
    try {
      return await _session.api.fetchOfficialEvidence(actorId);
    } catch (error) {
      if (!_isTransientFetchError(error)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _session.api.fetchOfficialEvidence(actorId);
    }
  }

  bool _isTransientFetchError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('connection closed') ||
        message.contains('connection reset');
  }

  String _friendlyEvidenceError(Object error) {
    final message = error.toString();
    if (message.contains('Fonte oficial temporariamente indisponivel')) {
      return message;
    }
    return 'Nao foi possivel carregar dados oficiais agora.';
  }

  Future<void> _follow(PoliticalActor actor) async {
    final current = _session.followedActor;
    if (current != null && current.id != actor.id) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trocar politico acompanhado?'),
          content: const Text('Voce pode trocar novamente quando quiser.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('TROCAR'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      await _session.followActor(actor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politico acompanhado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
    if (mounted) setState(() {});
  }

  void _changeFollowedActor() {
    Navigator.of(context, rootNavigator: true).pushNamed('/political-actors');
  }

  @override
  Widget build(BuildContext context) {
    final actor = ModalRoute.of(context)!.settings.arguments! as PoliticalActor;
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'FAROL POLITICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _ActorHeader(
                actor: actor,
                onFollow: () => _follow(actor),
                onChange: _changeFollowedActor,
                isFollowed: _session.followedActor?.id == actor.id,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(width: 4, height: 46, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'ATIVIDADES OFICIAIS\nDO MANDATO',
                    style: textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                _EvidenceError(
                  message: _error!,
                  onRetry: () => _loadEvidence(actor.id),
                ),
              if (!_loading && _session.evidence.isEmpty && _error == null)
                Text(
                  'Nenhuma evidencia recente encontrada na fonte oficial.',
                  style: textTheme.bodyMedium,
                ),
              if (_session.evidence.isNotEmpty)
                _EvidenceSections(evidence: _session.evidence),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorHeader extends StatelessWidget {
  final PoliticalActor actor;
  final VoidCallback onFollow;
  final VoidCallback onChange;
  final bool isFollowed;

  const _ActorHeader({
    required this.actor,
    required this.onFollow,
    required this.onChange,
    required this.isFollowed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(actor.displayName, style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '${actor.party ?? '--'} - ${actor.state ?? '--'} - ${actor.roleLabel}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isFollowed ? null : onFollow,
              child: Text(isFollowed ? 'ACOMPANHANDO' : 'ACOMPANHAR POLITICO'),
            ),
          ),
          if (isFollowed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onChange,
                child: const Text('TROCAR POLITICO'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EvidenceError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: textTheme.bodySmall),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('TENTAR NOVAMENTE'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _EvidenceSections extends StatelessWidget {
  final List<OfficialEvidence> evidence;

  const _EvidenceSections({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EvidenceSection(
          title: 'PROPOSICOES',
          emptyMessage: 'Nenhuma proposicao recente encontrada.',
          items: _itemsFor(EvidenceType.proposition),
        ),
        _EvidenceSection(
          title: 'DESPESAS PARLAMENTARES',
          emptyMessage: 'Nenhuma despesa recente encontrada.',
          items: _itemsFor(EvidenceType.expense),
        ),
        _EvidenceSection(
          title: 'VOTACOES RECENTES',
          emptyMessage: 'Nenhuma votacao recente encontrada nesta fase.',
          items: _itemsFor(EvidenceType.vote),
        ),
      ],
    );
  }

  List<OfficialEvidence> _itemsFor(EvidenceType type) {
    return evidence.where((item) => item.type == type).take(5).toList();
  }
}

class _EvidenceSection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<OfficialEvidence> items;

  const _EvidenceSection({
    required this.title,
    required this.emptyMessage,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.labelMedium),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(emptyMessage, style: textTheme.bodySmall)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EvidenceCard(evidence: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final OfficialEvidence evidence;

  const _EvidenceCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label(evidence.type), style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(evidence.title, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(evidence.summary, style: textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(evidence.sourceLabel, style: textTheme.labelSmall),
        ],
      ),
    );
  }

  String _label(EvidenceType type) {
    return switch (type) {
      EvidenceType.vote => 'VOTO OFICIAL',
      EvidenceType.proposition => 'PROPOSICAO',
      EvidenceType.expense => 'DESPESA PARLAMENTAR',
      EvidenceType.other => 'EVIDENCIA OFICIAL',
    };
  }
}
