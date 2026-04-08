import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
import '../../shared/models/party.dart';

class _PartyResult {
  final Party party;
  final double affinity;

  const _PartyResult({required this.party, required this.affinity});
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  int _navIndex = 3;

  final List<_PartyResult> _results = [
    _PartyResult(party: Party.getSampleParties()[0], affinity: 84.2),
    _PartyResult(party: Party.getSampleParties()[1], affinity: 78.1),
    _PartyResult(party: Party.getSampleParties()[2], affinity: 65.4),
    _PartyResult(party: Party.getSampleParties()[3], affinity: 42.0),
    _PartyResult(party: Party.getSampleParties()[4], affinity: 31.5),
    _PartyResult(party: Party.getSampleParties()[5], affinity: 28.7),
  ];

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        break;
      case 1:
        Navigator.pushNamed(context, '/quiz');
        break;
      case 2:
        Navigator.pushNamed(context, '/weighting');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topResult = _results.first;

    return AppScaffold(
      title: 'ELEIÇÃO 2026',
      currentNavIndex: _navIndex,
      onNavTap: _onNavTap,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text('SEU\nRESULTADO', style: textTheme.headlineLarge),
                ],
              ),
              const SizedBox(height: 32),
              _TopResultCard(result: topResult),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/comparison');
                  },
                  child: const Text('MAIS INFORMAÇÕES'),
                ),
              ),
              const SizedBox(height: 32),
              ...List.generate(_results.length - 1, (index) {
                final result = _results[index + 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PartyResultRow(result: result),
                );
              }),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Text(
                  'Um alto grau de concordância entre suas respostas e as de diversos partidos não significa necessariamente que essas partes sejam semelhantes em termos de conteúdo.',
                  style: textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/party-selection');
                  },
                  child: const Text('VOLTAR À SELEÇÃO'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/comparison');
                  },
                  child: const Text('VAMOS À AFINAÇÃO'),
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

class _TopResultCard extends StatelessWidget {
  final _PartyResult result;

  const _TopResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            'MELHOR AFINIDADE',
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    result.party.abbreviation,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${result.affinity.toStringAsFixed(1)}%',
                style: textTheme.displayMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.party.abbreviation,
            style: textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _PartyResultRow extends StatelessWidget {
  final _PartyResult result;

  const _PartyResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              result.party.abbreviation,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    result.party.abbreviation,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    '${result.affinity.toStringAsFixed(1)}%',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: result.affinity / 100,
                  minHeight: 4,
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
