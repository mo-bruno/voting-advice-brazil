import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';

void main() {
  group('Thesis.fromJson', () {
    test('uses theme_name as the category when present', () {
      final thesis = Thesis.fromJson({
        'id': 7,
        'text': 'O Estado deve ampliar investimentos em saude publica.',
        'theme_id': 3,
        'theme_name': 'Saude',
        'coverage': 0.82,
      });

      expect(thesis.id, 7);
      expect(
        thesis.title,
        'O Estado deve ampliar investimentos em saude publica.',
      );
      expect(thesis.category, 'Saude');
    });
  });

  group('Party.fromCandidateJson', () {
    test(
      'parses backend candidate list payload with numeric id and party_acronym',
      () {
        final party = Party.fromCandidateJson({
          'id': 13,
          'external_id': '280001607829',
          'name': 'Luiz Inacio Lula da Silva',
          'party_id': 1,
          'party_acronym': 'PT',
          'party_name': 'Partido dos Trabalhadores',
          'party_logo_url': '/data/logos/partidos/pt.png',
          'coalition': 'Brasil da Esperanca',
          'ballot_number': 13,
          'running_mate': 'Geraldo Alckmin',
          'spectrum': 'esquerda',
          'photo_url': null,
          'office': 'presidente',
          'state': null,
          'city': null,
          'election_year': 2022,
          'election_round': 1,
        });

        expect(party.id, '13');
        expect(party.name, 'Luiz Inacio Lula da Silva');
        expect(party.abbreviation, 'PT');
        expect(party.logoAsset, 'assets/logos/PT.png');
        expect(party.hasLogoAsset, isTrue);
        expect(party.description, contains('políticas sociais'));
      },
    );
  });

  group('CandidateResult.fromJson', () {
    test(
      'parses backend quiz result payload with numeric ids and party_acronym',
      () {
        final result = CandidateResult.fromJson({
          'candidate_id': 13,
          'name': 'Luiz Inacio Lula da Silva',
          'party_acronym': 'PT',
          'party_logo_url': '/data/logos/partidos/pt.png',
          'score_percent': 87.5,
          'score_by_theme': {
            'economia': 92.0,
            'saude': 83.0,
          },
          'rank': 1,
          'matches': [
            {
              'thesis_id': 7,
              'thesis_text':
                  'O Estado deve ampliar investimentos em saude publica.',
              'theme_id': 3,
              'user_answer': 'agree',
              'candidate_position': 'concordo',
              'match_type': 'exact',
            },
          ],
        });

        expect(result.candidateId, '13');
        expect(result.name, 'Luiz Inacio Lula da Silva');
        expect(result.party, 'PT');
        expect(result.scorePercent, 87.5);
        expect(result.rank, 1);
        expect(result.matches, hasLength(1));
        expect(result.matches.single.thesisId, 7);
        expect(result.matches.single.themeId, 3);
        expect(result.matches.single.themeId, isA<int>());
        expect(result.matches.single.userAnswerEnum, ThesisAnswer.agree);
        expect(result.matches.single.candidateAnswerEnum, ThesisAnswer.agree);
      },
    );
  });

  group('CandidateJustification.fromJson', () {
    test('parses backend justification payload', () {
      final justification = CandidateJustification.fromJson({
        'thesis_id': 7,
        'thesis_text': 'O Estado deve ampliar investimentos em saude publica.',
        'theme': 'saude',
        'theme_name': 'Saude',
        'position': 'concordo',
        'justification': 'Plano de governo defende fortalecimento do SUS.',
        'quote': null,
      });

      expect(justification.thesisId, 7);
      expect(
        justification.thesisText,
        'O Estado deve ampliar investimentos em saude publica.',
      );
      expect(justification.theme, 'saude');
      expect(justification.themeName, 'Saude');
      expect(justification.position, 'concordo');
      expect(justification.positionAnswer, ThesisAnswer.agree);
      expect(
        justification.justification,
        'Plano de governo defende fortalecimento do SUS.',
      );
    });
  });
}
