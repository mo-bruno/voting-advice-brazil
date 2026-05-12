import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/official_evidence.dart';
import '../../shared/models/political_actor.dart';
import '../../shared/political_actor_session.dart';

class PoliticalActorProfilePage extends StatefulWidget {
  const PoliticalActorProfilePage({super.key});

  @override
  State<PoliticalActorProfilePage> createState() =>
      _PoliticalActorProfilePageState();
}

class _PoliticalActorProfilePageState extends State<PoliticalActorProfilePage> {
  final _session = PoliticalActorSession.instance;
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
      final response = await _session.api.fetchOfficialEvidence(actorId);
      _session.evidence = response.evidence;
      _session.cacheStatus = response.cacheStatus;
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                isFollowed: _session.followedActor?.id == actor.id,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(width: 4, height: 46, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'O QUE ESSE POLITICO\nFEZ NO MANDATO?',
                    style: textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null) Text(_error!, style: textTheme.bodySmall),
              if (!_loading && _session.evidence.isEmpty && _error == null)
                Text(
                  'Nenhuma evidencia recente encontrada na fonte oficial.',
                  style: textTheme.bodyMedium,
                ),
              ..._session.evidence.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EvidenceCard(evidence: item),
                ),
              ),
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
  final bool isFollowed;

  const _ActorHeader({
    required this.actor,
    required this.onFollow,
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
              onPressed: onFollow,
              child: Text(isFollowed ? 'ACOMPANHANDO' : 'ACOMPANHAR POLITICO'),
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
