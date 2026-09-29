import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'result_share_data.dart';
import 'result_share_palette.dart';

class ResultShareControls extends StatelessWidget {
  const ResultShareControls({
    super.key,
    required this.data,
    required this.format,
    required this.palette,
    required this.rankingVariant,
    required this.enabled,
    required this.onVariantChanged,
    required this.onFormatChanged,
    required this.onPaletteChanged,
  });

  final ResultShareData data;
  final ResultShareFormat format;
  final ResultSharePalette palette;
  final ResultShareVariant rankingVariant;
  final bool enabled;
  final ValueChanged<ResultShareVariant> onVariantChanged;
  final ValueChanged<ResultShareFormat> onFormatChanged;
  final ValueChanged<ResultSharePalette> onPaletteChanged;

  Widget _choice(String label, bool selected, VoidCallback? onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: enabled && onTap != null ? (_) => onTap() : null,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.outlineVariant),
      labelStyle: TextStyle(
        color: selected ? AppTheme.background : AppTheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _choice('Maior alinhamento', !data.isRanking,
                () => onVariantChanged(ResultShareVariant.leader)),
            _choice('Ranking', data.isRanking,
                () => onVariantChanged(rankingVariant)),
          ],
        ),
        if (data.isRanking) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _choice('Top 5', data.variant == ResultShareVariant.topFive,
                  () => onVariantChanged(ResultShareVariant.topFive)),
              _choice(
                'Top 10',
                data.variant == ResultShareVariant.topTen,
                data.results.length > 5
                    ? () => onVariantChanged(ResultShareVariant.topTen)
                    : null,
              ),
            ],
          ),
          if (data.displayResults.length < data.variant.limit)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                data.results.length == 1
                    ? 'Há um candidato com afinidade calculada.'
                    : 'O ranking inclui ${data.displayResults.length} candidatos com afinidade calculada.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text('Cores da imagem', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in ResultSharePalette.values)
              MergeSemantics(
                  child: Semantics(
                selected: palette == option,
                child: Tooltip(
                  message: option.label,
                  child: IconButton(
                    onPressed: enabled ? () => onPaletteChanged(option) : null,
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: option.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette == option
                              ? AppTheme.onSurface
                              : AppTheme.outlineVariant,
                          width: palette == option ? 2 : 1,
                        ),
                      ),
                      child: palette == option
                          ? Icon(Icons.check_rounded,
                              size: 18, color: option.foreground)
                          : null,
                    ),
                  ),
                ),
              )),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<ResultShareFormat>(
          style: SegmentedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.onSurface,
            selectedBackgroundColor: AppTheme.primary,
            selectedForegroundColor: AppTheme.background,
            side: const BorderSide(color: AppTheme.outlineVariant),
          ),
          segments: const [
            ButtonSegment(
              value: ResultShareFormat.story,
              icon: Icon(Icons.crop_portrait_rounded),
              label: Text('Stories · 9:16'),
            ),
            ButtonSegment(
              value: ResultShareFormat.post,
              icon: Icon(Icons.crop_original_rounded),
              label: Text('Post · 4:5'),
            ),
          ],
          selected: {format},
          showSelectedIcon: false,
          onSelectionChanged:
              enabled ? (selection) => onFormatChanged(selection.first) : null,
        ),
      ],
    );
  }
}
