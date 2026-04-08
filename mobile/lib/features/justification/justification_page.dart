import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
import '../../shared/models/thesis.dart';
import '../../shared/models/party.dart';

class JustificationPage extends StatefulWidget {
  const JustificationPage({super.key});

  @override
  State<JustificationPage> createState() => _JustificationPageState();
}

class _JustificationPageState extends State<JustificationPage> {
  final List<Thesis> _theses = Thesis.getSampleTheses();
  final List<Party> _parties = Party.getSampleParties();
  int _currentIndex = 0;

  void _next() {
    if (_currentIndex < _theses.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Color _getIndicatorColor(ThesisAnswer answer) {
    switch (answer) {
      case ThesisAnswer.agree:
        return AppTheme.secondary;
      case ThesisAnswer.disagree:
        return AppTheme.error;
      case ThesisAnswer.neutral:
        return const Color(0xFFFBC02D);
      default:
        return AppTheme.surfaceContainerHighest;
    }
  }

  String _getPositionLabel(ThesisAnswer answer) {
    switch (answer) {
      case ThesisAnswer.agree:
        return 'A favor';
      case ThesisAnswer.disagree:
        return 'Contra';
      case ThesisAnswer.neutral:
        return 'Neutro';
      default:
        return 'Sem posição';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final thesis = _theses[_currentIndex];

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentIndex + 1}/\n${_theses.length}',
                          style: textTheme.headlineLarge?.copyWith(
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            thesis.title.toUpperCase(),
                            style: textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            (_currentIndex + 1) / _theses.length,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF88D982),
                                AppTheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      thesis.description,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ..._parties.take(5).map((party) {
                      final answer = party.positions[thesis.id] ??
                          ThesisAnswer.neutral;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PartyPositionCard(
                          party: party,
                          answer: answer,
                          indicatorColor: _getIndicatorColor(answer),
                          positionLabel: _getPositionLabel(answer),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.surface,
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previous,
                      child: const Text('TESE ANTERIOR'),
                    ),
                  ),
                if (_currentIndex > 0 &&
                    _currentIndex < _theses.length - 1)
                  const SizedBox(width: 12),
                if (_currentIndex < _theses.length - 1)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      child: const Text('PRÓXIMA TESE'),
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

class _PartyPositionCard extends StatelessWidget {
  final Party party;
  final ThesisAnswer answer;
  final Color indicatorColor;
  final String positionLabel;

  const _PartyPositionCard({
    required this.party,
    required this.answer,
    required this.indicatorColor,
    required this.positionLabel,
  });

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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    party.logoAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                party.abbreviation,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                positionLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getJustification(party, answer),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _getJustification(Party party, ThesisAnswer answer) {
    switch (answer) {
      case ThesisAnswer.agree:
        return '${party.name} defende esta posição como parte de sua plataforma política, alinhada com seus princípios fundamentais.';
      case ThesisAnswer.disagree:
        return '${party.name} se opõe a esta medida, considerando que ela contraria os interesses que o partido representa.';
      case ThesisAnswer.neutral:
        return '${party.name} não possui uma posição definida sobre este tema, mantendo neutralidade na discussão.';
      default:
        return '${party.name} ainda não se pronunciou oficialmente sobre este tema.';
    }
  }
}
