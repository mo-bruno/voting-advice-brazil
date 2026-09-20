import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/widgets/candidate_logo.dart';

void main() {
  testWidgets('renders the official candidate photo when it is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CandidatePortrait(
            photoUrl: 'https://example.test/data/fotos/2026/BR/123.jpg',
            candidateName: 'Candidata Teste',
            abbreviation: 'PT',
            logoAsset: 'assets/logos/PT.png',
            hasLogoAsset: true,
            size: 72,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('official-candidate-photo')),
    );
    expect(image.image, isA<NetworkImage>());
  });

  testWidgets('falls back to the party identity without a photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CandidatePortrait(
            photoUrl: null,
            candidateName: 'Candidata Teste',
            abbreviation: 'XYZ',
            logoAsset: 'assets/logos/XYZ.png',
            hasLogoAsset: false,
            size: 72,
          ),
        ),
      ),
    );

    expect(find.text('XYZ'), findsOneWidget);
  });
}
