import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_data.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';

const _result = CandidateResult(
  candidateId: '3',
  name: 'Joana & Luís',
  party: 'PSD',
  scorePercent: 72.5,
  rank: 1,
  matches: [],
  countedTheses: 10,
  answeredTheses: 30,
);

CandidateResult _candidate(int id, double score,
        {int? rank, String? name, int countedTheses = 10}) =>
    CandidateResult(
      candidateId: '$id',
      name: name ?? 'Candidatura $id',
      party: 'PSD',
      scorePercent: score,
      rank: rank ?? id,
      matches: [],
      countedTheses: countedTheses,
      answeredTheses: 30,
    );

void main() {
  test('recusa lista vazia', () {
    expect(() => ResultShareData(results: []), throwsArgumentError);
  });

  test('copia, ordena por afinidade e desempata pelo nome de forma estável',
      () {
    final input = [
      _candidate(1, 40),
      _candidate(2, 90, rank: 1, name: 'Beatriz'),
      _candidate(3, 90, rank: 2, name: 'ana'),
      _candidate(4, 90, rank: 3, name: 'Ana'),
    ];
    final data = ResultShareData(results: input);
    expect(input.map((result) => result.candidateId), ['1', '2', '3', '4']);
    expect(
        data.results.map((result) => result.candidateId), ['3', '4', '2', '1']);
    expect(data.result.candidateId, '3');
    input.clear();
    expect(data.results, hasLength(4));
    expect(() => data.results.clear(), throwsUnsupportedError);
    expect(() => data.displayResults.clear(), throwsUnsupportedError);
  });

  test('exclui candidaturas sem evidência e recusa lista sem base comparável',
      () {
    final unavailable = _candidate(1, 99, countedTheses: 0);
    final trueZero = _candidate(2, 0);
    final data = ResultShareData(
      results: [unavailable, trueZero, _result],
      variant: ResultShareVariant.topFive,
    );
    expect(data.results, [_result, trueZero]);
    expect(data.displayResults, [_result, trueZero]);
    expect(data.rankingTitle, 'Meus 2 alinhamentos.');
    expect(data.caption, isNot(contains(unavailable.name)));
    expect(data.caption, contains('Candidatura 2 (PSD) — 0%'));
    expect(() => ResultShareData(results: [unavailable]), throwsArgumentError);
  });

  test('seleciona líder, top 5 e top 10 sem completar resultados inexistentes',
      () {
    final data = ResultShareData(
      results: List.generate(
          12, (index) => _candidate(index + 1, 99 - index.toDouble())),
      publicUrl: 'https://exemplo.com.br/quiz/?privado=1',
    );
    expect(data.variant, ResultShareVariant.leader);
    expect(data.displayResults, [data.result]);
    expect(data.isRanking, isFalse);
    final five = data.withVariant(ResultShareVariant.topFive);
    expect(five.displayResults, hasLength(5));
    expect(five.displayResults.last.candidateId, '5');
    expect(five.rankingTitle, 'Meus 5 alinhamentos.');
    expect(five.isRanking, isTrue);
    expect(five.results, data.results);
    expect(five.siteUrl, 'https://exemplo.com.br/quiz/');
    final ten = five.withVariant(ResultShareVariant.topTen);
    expect(ten.displayResults, hasLength(10));
    expect(ten.displayResults.last.candidateId, '10');
    expect(ten.withVariant(ResultShareVariant.leader).displayResults,
        [data.result]);
    final onlyOne =
        ResultShareData(results: [_result], variant: ResultShareVariant.topTen);
    expect(onlyOne.displayResults, [_result]);
    expect(onlyOne.rankingTitle, 'Meu alinhamento.');
    final three = ResultShareData(
      results: data.results.take(3).toList(),
      variant: ResultShareVariant.topFive,
    );
    expect(three.rankingTitle, 'Meus 3 alinhamentos.');
    expect(three.displayResults, hasLength(3));
  });

  test('usa o novo domínio sem levar query, fragmento ou identidade privada',
      () {
    final data = ResultShareData(
      results: [_result],
      publicUrl:
          ' https://www.exemplo.com.br/quiz/?device_id=privado#respostas ',
    );
    expect(data.siteUrl, 'https://www.exemplo.com.br/quiz/');
    expect(data.siteLabel, 'exemplo.com.br/quiz');
    for (final network in ResultShareNetwork.values) {
      expect(data.networkUri(network).toString(), isNot(contains('privado')));
    }
  });

  test('configuração vazia ou inválida mantém o endereço público existente',
      () {
    for (final value in [
      '',
      'ainda-sem-dominio',
      'javascript:alert(1)',
      'https://usuario:senha@exemplo.com',
      'http://localhost:8000'
    ]) {
      expect(ResultShareData(results: [_result], publicUrl: value).siteUrl,
          'https://fpolitico.com.br');
    }
  });

  test('identifica o resultado como edição 2026', () {
    final data = ResultShareData(results: [_result]);
    expect(data.editionLabel, 'Edição 2026');
    expect(data.basisLabel, 'Quiz presidencial de 2026.');
    expect('2026'.allMatches(data.caption), hasLength(1));
    expect(data.caption, contains(data.basisLabel));
    expect(data.caption, isNot(contains('2022')));
  });

  test('legenda do líder mantém o escopo e codifica acentos e & nas redes', () {
    final data = ResultShareData(
      results: [_result, _candidate(7, 20)],
      publicUrl: 'https://exemplo.com.br',
    );
    expect(data.caption,
        contains('Minha maior afinidade foi de 72,5% com Joana & Luís (PSD)'));
    expect(data.caption, contains('entre os candidatos que comparei'));
    expect(data.caption, isNot(contains('Candidatura 7')));
    final twitter = data.networkUri(ResultShareNetwork.twitter);
    expect(twitter.host, 'twitter.com');
    expect(twitter.path, '/intent/tweet');
    expect(twitter.queryParameters, {
      'text': data.caption,
      'url': 'https://exemplo.com.br',
    });
    final whatsapp = data.networkUri(ResultShareNetwork.whatsapp);
    expect(whatsapp.host, 'wa.me');
    expect(whatsapp.queryParameters, {
      'text': '${data.caption}\nhttps://exemplo.com.br',
    });
  });

  test('ranking compartilha apenas nomes, partidos e percentuais selecionados',
      () {
    final data = ResultShareData(
      results: List.generate(
          12, (index) => _candidate(index + 1, 99 - index.toDouble())),
      variant: ResultShareVariant.topFive,
    );
    final caption = data.caption;
    expect(caption, contains('5 maiores alinhamentos'));
    for (var position = 1; position <= 5; position++) {
      expect(
          caption,
          contains(
              '$position. Candidatura $position (PSD) — ${100 - position}%'));
    }
    expect(caption, isNot(contains('Candidatura 6')));
    expect(caption, contains('entre os candidatos que comparei'));
    expect(data.networkUri(ResultShareNetwork.whatsapp).queryParameters['text'],
        '$caption\n${data.siteUrl}');
  });

  test('X usa resumo curto do ranking com a quantidade real e link separado',
      () {
    final data = ResultShareData(
      results: List.generate(
          12, (index) => _candidate(index + 1, 99 - index.toDouble())),
      variant: ResultShareVariant.topTen,
    );
    final twitter = data.networkUri(ResultShareNetwork.twitter).queryParameters;
    expect(twitter['text'], contains('10 maiores alinhamentos'));
    expect(twitter['text'], contains(data.basisLabel));
    expect('2026'.allMatches(twitter['text']!), hasLength(1));
    expect(twitter['text'], isNot(contains('Candidatura')));
    expect(twitter['text']!.length + 24, lessThanOrEqualTo(280));
    expect(twitter['url'], data.siteUrl);
    final three = ResultShareData(
        results: data.results.take(3).toList(),
        variant: ResultShareVariant.topTen);
    expect(three.networkUri(ResultShareNetwork.twitter).queryParameters['text'],
        contains('3 maiores alinhamentos'));
    final one = ResultShareData(
        results: [_result], variant: ResultShareVariant.topFive);
    expect(one.caption, contains('meu maior alinhamento'));
    expect(one.networkUri(ResultShareNetwork.twitter).queryParameters['text'],
        contains('Meu maior alinhamento'));
  });

  test('percentuais usam vírgula e omitem decimal zero', () {
    expect(ResultShareData.formatPercent(87.5), '87,5');
    expect(ResultShareData.formatPercent(87), '87');
    expect(ResultShareData(results: [_result]).percent, '72,5');
  });
}
