import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
import '../../shared/models/thesis.dart';
import '../../shared/models/party.dart';

class ComparisonPage extends StatelessWidget {
  const ComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theses = Thesis.getSampleTheses();
    final parties = Party.getSampleParties();
    final party1 = parties[0];
    final party2 = parties[5];

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      actions: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/results'),
          child: Text('RESULTADOS', style: textTheme.labelMedium),
        ),
      ],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'COMPARAÇÃO\nDE PARTIDOS',
                style: textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Compare suas posições diretamente com as respostas dos partidos selecionados nos temas mais importantes.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _ComparisonHeader(party1: party1, party2: party2),
              const SizedBox(height: 4),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: theses.length > 5 ? 5 : theses.length,
                separatorBuilder: (_, __) => const Divider(
                  color: AppTheme.outlineVariant,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final thesis = theses[index];
                  return _ComparisonRow(
                    index: index + 1,
                    thesis: thesis,
                    party1: party1,
                    party2: party2,
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/results'),
                  child: const Text('VOLTAR PARA A VISÃO GERAL'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/party-selection');
                  },
                  child: const Text('OUTROS PARTIDOS'),
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

class _ComparisonHeader extends StatelessWidget {
  final Party party1;
  final Party party2;

  const _ComparisonHeader({required this.party1, required this.party2});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppTheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('TEMA', style: textTheme.labelSmall),
          ),
          SizedBox(
            width: 50,
            child: Text(
              'VOCÊ',
              style: textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              party1.abbreviation,
              style: textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              party2.abbreviation,
              style: textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final int index;
  final Thesis thesis;
  final Party party1;
  final Party party2;

  const _ComparisonRow({
    required this.index,
    required this.thesis,
    required this.party1,
    required this.party2,
  });

  Widget _buildIndicator(ThesisAnswer answer) {
    IconData icon;
    Color color;
    switch (answer) {
      case ThesisAnswer.agree:
        icon = Icons.check;
        color = AppTheme.secondary;
        break;
      case ThesisAnswer.disagree:
        icon = Icons.close;
        color = AppTheme.error;
        break;
      case ThesisAnswer.neutral:
        icon = Icons.remove;
        color = AppTheme.onSurfaceVariant;
        break;
      default:
        icon = Icons.remove;
        color = AppTheme.surfaceContainerHighest;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final userAnswer = thesis.answer;
    final p1Answer = party1.positions[thesis.id] ?? ThesisAnswer.neutral;
    final p2Answer = party2.positions[thesis.id] ?? ThesisAnswer.neutral;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$index. ${thesis.title.toUpperCase()}',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Center(child: _buildIndicator(userAnswer)),
          ),
          SizedBox(
            width: 50,
            child: Center(child: _buildIndicator(p1Answer)),
          ),
          SizedBox(
            width: 50,
            child: Center(child: _buildIndicator(p2Answer)),
          ),
        ],
      ),
    );
  }
}
