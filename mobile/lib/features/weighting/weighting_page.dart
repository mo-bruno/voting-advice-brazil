import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
import '../../shared/models/thesis.dart';

class WeightingPage extends StatefulWidget {
  const WeightingPage({super.key});

  @override
  State<WeightingPage> createState() => _WeightingPageState();
}

class _WeightingPageState extends State<WeightingPage> {
  final List<Thesis> _theses = Thesis.getSampleTheses();

  void _toggleWeight(int index) {
    setState(() {
      _theses[index].doubleWeight = !_theses[index].doubleWeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      actions: [
        TextButton(
          onPressed: () {},
          child: Text('TEMAS', style: textTheme.labelMedium),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/party-selection'),
          child: Text('PARTIDOS', style: textTheme.labelMedium),
        ),
      ],
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'PESO DOS\nTEMAS',
                            style: textTheme.displayMedium,
                          ),
                        ),
                        Text(
                          'PASSO 2 DE 3',
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quais temas são especialmente importantes para você? Marque os temas que devem ter peso duplo no cálculo.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _theses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _ThemeWeightCard(
                          thesis: _theses[index],
                          index: index + 1,
                          onToggle: () => _toggleWeight(index),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('VOLTAR PARA AS QUESTÕES'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/party-selection');
                    },
                    child: const Text('CONTINUAR PARA SELEÇÃO'),
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

class _ThemeWeightCard extends StatelessWidget {
  final Thesis thesis;
  final int index;
  final VoidCallback onToggle;

  const _ThemeWeightCard({
    required this.thesis,
    required this.index,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMA $index',
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  thesis.title,
                  style: textTheme.titleLarge,
                ),
                if (thesis.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    thesis.description,
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: thesis.doubleWeight
                    ? AppTheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: thesis.doubleWeight
                      ? AppTheme.primary
                      : AppTheme.outlineVariant,
                ),
              ),
              child: Text(
                'x2',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: thesis.doubleWeight
                      ? AppTheme.background
                      : AppTheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
