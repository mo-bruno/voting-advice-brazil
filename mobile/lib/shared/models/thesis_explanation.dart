class ExplanationSource {
  final String title;
  final Uri url;

  const ExplanationSource({required this.title, required this.url});

  factory ExplanationSource.fromJson(Map<String, dynamic> json) {
    final url = Uri.parse(json['url'] as String);
    if ((url.scheme != 'https' && url.scheme != 'http') || url.host.isEmpty) {
      throw const FormatException('Endereço da fonte inválido.');
    }
    return ExplanationSource(title: json['title'] as String, url: url);
  }
}

class ThesisExplanation {
  final List<String> paragraphs;
  final List<ExplanationSource> sources;

  const ThesisExplanation({required this.paragraphs, required this.sources});

  factory ThesisExplanation.fromJson(Map<String, dynamic> json) {
    return ThesisExplanation(
      paragraphs: List<String>.unmodifiable(
        (json['paragraphs'] as List<dynamic>).cast<String>(),
      ),
      sources: List<ExplanationSource>.unmodifiable(
        (json['sources'] as List<dynamic>).map(
          (source) =>
              ExplanationSource.fromJson(source as Map<String, dynamic>),
        ),
      ),
    );
  }
}
