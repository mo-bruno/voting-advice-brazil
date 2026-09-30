import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('private community identity contract', () {
    const credential = '7af124cd-912f-45a3-830b-9ec63c8a91a6';
    final postJson = {
      'id': 'post-1',
      'author_alias': 'u/abc123def0',
      'is_mine': true,
      'content': 'Texto',
      'political_actor_id': null,
      'theme_slug': null,
      'score': 0,
      'created_at': '2026-09-09T12:00:00Z',
      'removed': false,
      'removed_by': null,
    };
    final commentJson = {
      'id': 'comment-1',
      'post_id': 'post-1',
      'author_alias': 'u/def456abc0',
      'is_mine': false,
      'content': 'Comentário',
      'created_at': '2026-09-09T12:01:00Z',
    };

    test('list and detail send the private header and parse public aliases',
        () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode(
                request.url.path.endsWith('/post-1')
                    ? {
                        'post': postJson,
                        'comments': [commentJson]
                      }
                    : {
                        'posts': [postJson],
                        'has_next': false
                      },
              ),
              200);
        }),
      );

      final list = await api.listPosts(anonymousId: credential);
      final post = PostSummary.fromJson(
          (list['posts'] as List).single as Map<String, dynamic>);
      final detail = PostDetail.fromJson(
          await api.getPost('post-1', anonymousId: credential));

      expect(post.authorAlias, 'u/abc123def0');
      expect(post.isMine, isTrue);
      expect(detail.post.authorAlias, 'u/abc123def0');
      expect(detail.post.isMine, isTrue);
      expect(detail.comments.single.authorAlias, 'u/def456abc0');
      expect(detail.comments.single.isMine, isFalse);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/v1/community/posts',
        'GET /api/v1/community/posts/post-1',
      ]);
      for (final request in requests) {
        expect(request.headers['X-Farol-Anonymous-Id'], credential);
        expect(request.url.toString(), isNot(contains(credential)));
        expect(request.url.queryParameters, isNot(contains('anonymous_id')));
        expect(request.body, isEmpty);
      }
    });

    test('protected community actions keep credentials only in the header',
        () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode(
                request.url.path.endsWith('/comments') ? commentJson : postJson,
              ),
              200);
        }),
      );

      final created = PostSummary.fromJson(
          await api.createPost(anonymousId: credential, content: 'Texto'));
      final voted = PostSummary.fromJson(
          await api.votePost('post-1', 1, anonymousId: credential));
      final comment = PostComment.fromJson(await api
          .createComment('post-1', 'Comentário', anonymousId: credential));
      await api.reportPost('post-1', reason: 'spam', anonymousId: credential);
      await api.deletePost('post-1', anonymousId: credential);

      expect(created.authorAlias, 'u/abc123def0');
      expect(voted.isMine, isTrue);
      expect(comment.authorAlias, 'u/def456abc0');
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/v1/community/posts',
        'POST /api/v1/community/posts/post-1/votes',
        'POST /api/v1/community/posts/post-1/comments',
        'POST /api/v1/community/posts/post-1/reports',
        'DELETE /api/v1/community/posts/post-1',
      ]);
      for (final request in requests) {
        expect(request.headers['X-Farol-Anonymous-Id'], credential);
        expect(request.url.toString(), isNot(contains(credential)));
        expect(request.body, isNot(contains(credential)));
        expect(request.body, isNot(contains('anonymous_id')));
        expect(request.body, isNot(contains('author_alias')));
        expect(request.body, isNot(contains('is_mine')));
      }
      expect(jsonDecode(requests[0].body), {'content': 'Texto'});
      expect(jsonDecode(requests[1].body), {'value': 1});
      expect(jsonDecode(requests[2].body), {'content': 'Comentário'});
      expect(jsonDecode(requests[3].body), {'reason': 'spam'});
      expect(requests[4].body, isEmpty);
    });
  });

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
          'photo_url': '/data/fotos/2026/BR/280002542548.jpg',
          'office': 'presidente',
          'state': null,
          'city': null,
          'election_year': 2022,
          'election_round': 1,
          'official_status': 'AGUARDANDO JULGAMENTO',
          'source_snapshot': '20/09/2026 08:30:57',
        });

        expect(party.id, '13');
        expect(party.name, 'Luiz Inacio Lula da Silva');
        expect(party.abbreviation, 'PT');
        expect(party.logoAsset, 'assets/logos/PT.png');
        expect(party.hasLogoAsset, isTrue);
        expect(party.photoUrl, '/data/fotos/2026/BR/280002542548.jpg');
        expect(party.description, contains('plano oficial de governo'));
        expect(party.officialStatus, 'AGUARDANDO JULGAMENTO');
        expect(party.sourceSnapshot, '20/09/2026 08:30:57');
      },
    );
  });

  group('CandidateResult.fromJson', () {
    Map<String, dynamic> payload(List<Map<String, dynamic>> matches) => {
          'candidate_id': 1,
          'name': 'Candidata',
          'party_acronym': 'PT',
          'score_percent': 0,
          'rank': 0,
          'matches': matches,
        };

    Map<String, dynamic> match(int id, String user, String candidate) => {
          'thesis_id': id,
          'thesis_text': 'Tese $id',
          'theme_id': 1,
          'user_answer': user,
          'candidate_position': candidate,
          'match_type': 'skipped',
        };

    test('legacy payload counts only answered theses with evidence', () {
      final result = CandidateResult.fromJson(
        payload([
          match(1, 'agree', 'concordo'),
          match(2, 'disagree', 'sem_posicao'),
          match(3, 'skip', 'concordo'),
          match(4, 'neutral', 'neutro'),
        ]),
      );
      expect(result.answeredTheses, 3);
      expect(result.countedTheses, 2);
      expect(result.hasComparableEvidence, isTrue);
    });

    test('legacy payload cannot opt into the beta ranking implicitly', () {
      final result = CandidateResult.fromJson({
        ...payload([
          match(1, 'agree', 'concordo'),
          match(2, 'agree', 'concordo'),
          match(3, 'agree', 'concordo'),
          match(4, 'agree', 'concordo'),
          match(5, 'agree', 'concordo'),
        ]),
        'rank': 1,
      });

      expect(result.rankingEligible, isFalse);
    });

    test('no evidence does not become a zero affinity label', () {
      final result = CandidateResult.fromJson(
        payload([match(1, 'agree', 'sem_posicao')]),
      );
      expect(result.hasComparableEvidence, isFalse);
      expect(result.rankingEligible, isFalse);
      expect(result.affinityLabel, 'Fora do ranking desta edição');
      expect(
          result.coverageLabel, '0 de 1 respostas comparáveis · 0 categorias');
    });

    test('explicit counts take precedence over incomplete legacy matches', () {
      final result = CandidateResult.fromJson({
        ...payload([]),
        'counted_theses': 2,
        'answered_theses': 9,
        'score_percent': 100,
        'comparable_categories': 2,
        'documented_theses': 2,
        'documented_categories': 2,
        'ranking_status': 'insufficient_documented_coverage',
        'ranking_eligible': false,
      });
      expect(result.hasComparableEvidence, isTrue);
      expect(result.rankingEligible, isFalse);
      expect(result.affinityLabel, 'Fora do ranking desta edição');
      expect(
          result.coverageLabel, '2 de 9 respostas comparáveis · 2 categorias');
      expect(
        result.rankingExplanation,
        'O plano oferece posições comparáveis em 2 teses e 2 categorias. '
        'Esta edição exige pelo menos 5 teses e 4 categorias.',
      );
    });

    test(
      'parses backend quiz result payload with numeric ids and party_acronym',
      () {
        final result = CandidateResult.fromJson({
          'candidate_id': 13,
          'name': 'Luiz Inacio Lula da Silva',
          'party_acronym': 'PT',
          'party_logo_url': '/data/logos/partidos/pt.png',
          'photo_url': '/data/fotos/2026/BR/280002542548.jpg',
          'score_percent': 87.5,
          'score_by_theme': {'economia': 92.0, 'saude': 83.0},
          'rank': 1,
          'counted_theses': 7,
          'answered_theses': 12,
          'comparable_categories': 4,
          'documented_theses': 11,
          'documented_categories': 7,
          'ranking_status': 'eligible',
          'ranking_eligible': true,
          'matches': [
            {
              'thesis_id': 7,
              'thesis_text':
                  'O Estado deve ampliar investimentos em saude publica.',
              'theme_id': 3,
              'user_answer': 'agree',
              'candidate_position': 'concordo',
              'candidate_analysis': 'CONCORDA',
              'match_type': 'exact',
            },
          ],
        });

        expect(result.candidateId, '13');
        expect(result.name, 'Luiz Inacio Lula da Silva');
        expect(result.party, 'PT');
        expect(result.photoUrl, '/data/fotos/2026/BR/280002542548.jpg');
        expect(result.scorePercent, 87.5);
        expect(result.rank, 1);
        expect(result.rankingEligible, isTrue);
        expect(result.rankingStatus, 'eligible');
        expect(result.comparableCategories, 4);
        expect(result.documentedTheses, 11);
        expect(result.documentedCategories, 7);
        expect(result.affinityLabel, '1º lugar');
        expect(
          result.coverageLabel,
          '7 de 12 respostas comparáveis · 4 categorias',
        );
        expect(result.matches, hasLength(1));
        expect(result.matches.single.thesisId, 7);
        expect(result.matches.single.themeId, 3);
        expect(result.matches.single.themeId, isA<int>());
        expect(result.matches.single.userAnswerEnum, ThesisAnswer.agree);
        expect(result.matches.single.candidateAnswerEnum, ThesisAnswer.agree);
        expect(result.matches.single.candidateAnalysis, 'CONCORDA');
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
        'analytical_position': 'CONCORDA',
        'justification': 'Plano de governo defende fortalecimento do SUS.',
        'quote': 'Fortalecer o SUS',
        'source_ref': 'PG_2026_BR_123_01#page=4',
        'source_url': 'https://example.test/plano.pdf',
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
      expect(justification.analyticalPosition, 'CONCORDA');
      expect(justification.quote, 'Fortalecer o SUS');
      expect(justification.sourceRef, 'PG_2026_BR_123_01#page=4');
      expect(justification.sourceUrl, 'https://example.test/plano.pdf');
      expect(
        justification.justification,
        'Plano de governo defende fortalecimento do SUS.',
      );
    });
  });
}
