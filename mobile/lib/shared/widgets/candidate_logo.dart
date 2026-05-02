import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/candidate_result.dart';

class CandidateLogo extends StatelessWidget {
  final CandidateResult result;
  final double size;

  const CandidateLogo({
    super.key,
    required this.result,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: result.hasLogoAsset
            ? Image.asset(
                result.logoAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _FallbackLogo(result: result),
              )
            : _FallbackLogo(result: result),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final CandidateResult result;

  const _FallbackLogo({required this.result});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        result.abbreviation,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppTheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
