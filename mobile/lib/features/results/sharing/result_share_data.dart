import '../../../shared/models/candidate_result.dart';

enum ResultShareFormat {
  story('Stories', 640, '1080 × 1920'),
  post('Post', 450, '1080 × 1350');

  const ResultShareFormat(this.label, this.height, this.resolution);

  final String label;
  final double height;
  final String resolution;
  double get aspectRatio => 360 / height;
  String get fileName => 'meu-resultado-farol-$name.png';
}

enum ResultShareNetwork { twitter, whatsapp }

enum ResultShareVariant {
  leader(1),
  topFive(5),
  topTen(10);

  const ResultShareVariant(this.limit);

  final int limit;
}

/// Apenas o resultado que a pessoa decidiu mostrar. Nunca inclui respostas,
/// identidade local ou parâmetros privados da URL em que o quiz foi aberto.
class ResultShareData {
  ResultShareData({
    required List<CandidateResult> results,
    String? publicUrl,
    this.variant = ResultShareVariant.leader,
  })  : results = _sortedResults(results),
        siteUri = _siteUri(publicUrl ?? _configuredUrl);

  ResultShareData._({
    required this.results,
    required this.siteUri,
    required this.variant,
  });

  static const defaultUrl = 'https://fpolitico.com.br';
  static const _configuredUrl = String.fromEnvironment(
    'PUBLIC_APP_URL',
    defaultValue: defaultUrl,
  );

  final List<CandidateResult> results;
  final Uri siteUri;
  final ResultShareVariant variant;

  CandidateResult get result => results.first;
  List<CandidateResult> get displayResults =>
      List.unmodifiable(results.take(variant.limit));
  bool get isRanking => variant != ResultShareVariant.leader;
  String get rankingTitle => displayResults.length == 1
      ? 'Meu alinhamento'
      : 'Meu ranking de afinidade';
  String get editionLabel => 'Edição 2026';
  String get basisLabel => 'Quiz presidencial de 2026 · Beta.';

  ResultShareData withVariant(ResultShareVariant variant) => ResultShareData._(
        results: results,
        siteUri: siteUri,
        variant: variant,
      );

  static List<CandidateResult> _sortedResults(List<CandidateResult> results) {
    final indexed =
        results.indexed.where((entry) => entry.$2.rankingEligible).toList();
    if (indexed.isEmpty) {
      throw ArgumentError.value(
          results, 'results', 'É necessário um resultado elegível ao ranking.');
    }
    indexed.sort((a, b) {
      final rankOrder = a.$2.rank.compareTo(b.$2.rank);
      if (rankOrder != 0) return rankOrder;
      final nameOrder =
          a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase());
      return nameOrder != 0 ? nameOrder : a.$1.compareTo(b.$1);
    });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
  }

  static Uri _siteUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return Uri.parse(defaultUrl);
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
  }

  String get siteUrl => siteUri.toString();
  String get siteLabel => '${siteUri.authority}${siteUri.path}'
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'/$'), '');

  String get caption {
    if (!isRanking) {
      return 'Fiz o quiz do Farol Político! Meu maior alinhamento neste teste '
          'foi com ${result.name} (${result.abbreviation}), entre os candidatos '
          'que comparei. Base: ${result.coverageLabel}. $basisLabel';
    }
    final selected = displayResults;
    final introduction = selected.length == 1
        ? 'Este é meu maior alinhamento'
        : 'Estes são meus ${selected.length} maiores alinhamentos';
    final ranking = selected.indexed.map((entry) {
      final candidate = entry.$2;
      return '${candidate.rank}º. ${candidate.name} '
          '(${candidate.abbreviation}) — ${candidate.coverageLabel}';
    }).join('\n');
    return 'Fiz o quiz do Farol Político! $introduction entre os candidatos '
        'que comparei:\n$ranking\n$basisLabel';
  }

  String get _twitterCaption {
    if (!isRanking) return caption;
    final selected = displayResults;
    final summary = selected.length == 1
        ? 'Meu maior alinhamento'
        : 'Meus ${selected.length} maiores alinhamentos';
    return 'Fiz o quiz do Farol Político! $summary entre os candidatos '
        'que comparei. $basisLabel';
  }

  Uri networkUri(ResultShareNetwork network) => switch (network) {
        ResultShareNetwork.twitter =>
          Uri.https('twitter.com', '/intent/tweet', {
            'text': _twitterCaption,
            'url': siteUrl,
          }),
        ResultShareNetwork.whatsapp => Uri.https('wa.me', '/', {
            'text': '$caption\n$siteUrl',
          }),
      };
}
