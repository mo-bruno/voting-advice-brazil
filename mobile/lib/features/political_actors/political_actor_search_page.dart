import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/political_actor.dart';
import '../../shared/political_actor_session.dart';

class PoliticalActorSearchPage extends StatefulWidget {
  const PoliticalActorSearchPage({super.key});

  @override
  State<PoliticalActorSearchPage> createState() =>
      _PoliticalActorSearchPageState();
}

class _PoliticalActorSearchPageState extends State<PoliticalActorSearchPage> {
  final _session = PoliticalActorSession.instance;
  final _controller = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrending());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _session.trending = await _session.api.fetchTrendingPoliticalActors();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      setState(() => _session.searchResults = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _session.api.fetchPoliticalActors(search: value);
      _session.searchResults = response.actors;
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openActor(PoliticalActor actor) {
    Navigator.pushNamed(context, '/political-actor-profile', arguments: actor);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasQuery = _controller.text.trim().isNotEmpty;

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
              Row(
                children: [
                  Container(width: 4, height: 40, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text('ACOMPANHAR\nPOLITICO', style: textTheme.headlineLarge),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Nesta fase, estamos comecando por deputados federais. Mais cargos serao adicionados depois.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Busque por nome, partido ou estado',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null) Text(_error!, style: textTheme.bodySmall),
              if (!hasQuery && _session.trending.isNotEmpty)
                _TrendingActorsSection(
                  items: _session.trending,
                  onTap: _openActor,
                ),
              if (hasQuery)
                ..._session.searchResults.map(
                  (actor) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PoliticalActorListItem(
                      actor: actor,
                      onTap: () => _openActor(actor),
                    ),
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

class _TrendingActorsSection extends StatelessWidget {
  final List<TrendingPoliticalActor> items;
  final ValueChanged<PoliticalActor> onTap;

  const _TrendingActorsSection({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MAIS ACOMPANHADOS', style: textTheme.labelMedium),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PoliticalActorListItem(
              actor: item.actor,
              rank: item.rank,
              onTap: () => onTap(item.actor),
            ),
          ),
        ),
      ],
    );
  }
}

class _PoliticalActorListItem extends StatelessWidget {
  final PoliticalActor actor;
  final int? rank;
  final VoidCallback onTap;

  const _PoliticalActorListItem({
    required this.actor,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(actor.displayName, style: textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${actor.party ?? '--'} - ${actor.state ?? '--'} - ${actor.roleLabel}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (rank != null) Text('#$rank', style: textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
