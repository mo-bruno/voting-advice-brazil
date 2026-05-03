import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/thesis.dart';
import '../../shared/quiz_session.dart';

class WeightingPage extends StatefulWidget {
  const WeightingPage({super.key});

  @override
  State<WeightingPage> createState() => _WeightingPageState();
}

class _WeightingPageState extends State<WeightingPage> {
  final QuizSession _session = QuizSession.instance;
  int? _editingThesisId;

  List<Thesis> get _theses => _session.theses;

  void _toggleWeight(int index) {
    setState(() {
      _theses[index].doubleWeight = !_theses[index].doubleWeight;
    });
  }

  void _toggleEditor(Thesis thesis) {
    setState(() {
      _editingThesisId = _editingThesisId == thesis.id ? null : thesis.id;
    });
  }

  void _setAnswer(Thesis thesis, ThesisAnswer answer) {
    setState(() {
      thesis.answer = answer;
      _editingThesisId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'FAROL POLÍTICO',
      body: _theses.isEmpty ? _emptyState(context) : _content(context),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Responda o quiz antes de escolher os pesos.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/quiz'),
              child: const Text('IR PARA O QUIZ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
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
                      Text('PASSO 2 DE 3', style: textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Marque as perguntas que devem ter peso duplo no cálculo.',
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
                        onEdit: () => _toggleEditor(_theses[index]),
                        isEditing: _editingThesisId == _theses[index].id,
                        onAnswerSelected: (answer) {
                          _setAnswer(_theses[index], answer);
                        },
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/party-selection');
              },
              child: const Text('CONTINUAR PARA SELEÇÃO'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeWeightCard extends StatelessWidget {
  final Thesis thesis;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final bool isEditing;
  final ValueChanged<ThesisAnswer> onAnswerSelected;

  const _ThemeWeightCard({
    required this.thesis,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.isEditing,
    required this.onAnswerSelected,
  });

  String get _answerLabel {
    switch (thesis.answer) {
      case ThesisAnswer.agree:
        return 'Concordo';
      case ThesisAnswer.neutral:
        return 'Neutro';
      case ThesisAnswer.disagree:
        return 'Discordo';
      case ThesisAnswer.skipped:
        return 'Pulada';
      case ThesisAnswer.unanswered:
        return 'Sem resposta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(
          color: isEditing ? AppTheme.primary : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PERGUNTA $index', style: textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(thesis.title, style: textTheme.titleLarge),
                      if (thesis.category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(thesis.category, style: textTheme.bodySmall),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Resposta: $_answerLabel',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color:
                              isEditing ? AppTheme.primary : Colors.transparent,
                          border: Border.all(
                            color: isEditing
                                ? AppTheme.primary
                                : AppTheme.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: isEditing
                              ? AppTheme.background
                              : AppTheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _InlineAnswerEditor(
              currentAnswer: thesis.answer,
              onSelected: onAnswerSelected,
            ),
            crossFadeState: isEditing
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
          ),
        ],
      ),
    );
  }
}

class _InlineAnswerEditor extends StatelessWidget {
  final ThesisAnswer currentAnswer;
  final ValueChanged<ThesisAnswer> onSelected;

  const _InlineAnswerEditor({
    required this.currentAnswer,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: AppTheme.outlineVariant, height: 1),
          const SizedBox(height: 12),
          Text('EDITAR RESPOSTA',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnswerEditButton(
                label: 'CONCORDO',
                icon: Icons.thumb_up,
                isSelected: currentAnswer == ThesisAnswer.agree,
                onPressed: () => onSelected(ThesisAnswer.agree),
              ),
              _AnswerEditButton(
                label: 'NEUTRO',
                icon: Icons.help_outline,
                isSelected: currentAnswer == ThesisAnswer.neutral,
                onPressed: () => onSelected(ThesisAnswer.neutral),
              ),
              _AnswerEditButton(
                label: 'DISCORDO',
                icon: Icons.thumb_down,
                isSelected: currentAnswer == ThesisAnswer.disagree,
                onPressed: () => onSelected(ThesisAnswer.disagree),
              ),
              _AnswerEditButton(
                label: 'PULAR',
                icon: Icons.skip_next,
                isSelected: currentAnswer == ThesisAnswer.skipped,
                onPressed: () => onSelected(ThesisAnswer.skipped),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerEditButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AnswerEditButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primary : Colors.transparent,
        foregroundColor: isSelected ? AppTheme.background : AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
