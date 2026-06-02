import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/widgets/candidate_logo.dart';

void main() {
  testWidgets('candidate logo exposes a semantic label', (tester) async {
    const result = CandidateResult(
      candidateId: '13',
      name: 'Partido dos Trabalhadores',
      party: 'PT',
      scorePercent: 92,
      rank: 1,
      matches: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CandidateLogo(result: result, size: 48),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Logo PT'), findsOneWidget);
  });
}
