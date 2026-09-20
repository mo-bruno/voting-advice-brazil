import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/candidate_result.dart';

class CandidateLogo extends StatelessWidget {
  final CandidateResult result;
  final double size;

  const CandidateLogo({super.key, required this.result, required this.size});

  @override
  Widget build(BuildContext context) {
    return CandidatePortrait(
      photoUrl: result.photoUrl,
      candidateName: result.name,
      abbreviation: result.abbreviation,
      logoAsset: result.logoAsset,
      hasLogoAsset: result.hasLogoAsset,
      size: size,
    );
  }
}

class CandidatePortrait extends StatelessWidget {
  final String? photoUrl;
  final String candidateName;
  final String abbreviation;
  final String logoAsset;
  final bool hasLogoAsset;
  final double size;

  const CandidatePortrait({
    super.key,
    required this.photoUrl,
    required this.candidateName,
    required this.abbreviation,
    required this.logoAsset,
    required this.hasLogoAsset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final fallback = Semantics(
      image: true,
      label: 'Identificação partidária de $candidateName',
      child: _FallbackLogo(
        abbreviation: abbreviation,
        logoAsset: logoAsset,
        hasLogoAsset: hasLogoAsset,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: !hasPhoto
          ? fallback
          : Image.network(
              photoUrl!,
              key: const ValueKey('official-candidate-photo'),
              semanticLabel: 'Foto oficial de $candidateName',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : fallback,
            ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final String abbreviation;
  final String logoAsset;
  final bool hasLogoAsset;

  const _FallbackLogo({
    required this.abbreviation,
    required this.logoAsset,
    required this.hasLogoAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: hasLogoAsset
          ? Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _Abbreviation(abbreviation),
            )
          : _Abbreviation(abbreviation),
    );
  }
}

class _Abbreviation extends StatelessWidget {
  final String value;

  const _Abbreviation(this.value);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value,
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
