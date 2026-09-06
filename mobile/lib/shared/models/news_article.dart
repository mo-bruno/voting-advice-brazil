/// Uma notícia vinda de `GET /api/v1/news/weekly`.
///
/// A formatação de data e de tempo de leitura vive aqui porque é a mesma em
/// toda a tela — deixá-la no widget espalharia a mesma lógica por dois lugares.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.imageUrl,
    required this.themeSlug,
    required this.themeLabel,
    required this.publishedAt,
    required this.readingMinutes,
    required this.url,
  });

  final String id;
  final String title;
  final String summary;
  final String? imageUrl;
  final String themeSlug;
  final String themeLabel;
  final DateTime publishedAt;
  final int readingMinutes;
  final String url;

  static const List<String> _monthsAbbr = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      themeSlug: json['theme_slug'] as String? ?? '',
      themeLabel: json['theme_label'] as String? ?? '',
      publishedAt: DateTime.parse(json['published_at'] as String).toLocal(),
      readingMinutes: json['reading_minutes'] as int? ?? 1,
      url: json['url'] as String,
    );
  }

  /// Ex.: `04 DE SET. DE 2026`
  String get formattedDate {
    final day = publishedAt.day.toString().padLeft(2, '0');
    return '$day DE ${_monthsAbbr[publishedAt.month - 1]}. DE ${publishedAt.year}';
  }

  /// Ex.: `2 MIN DE LEITURA`
  String get readingLabel => '$readingMinutes MIN DE LEITURA';

  /// Usada no lugar da miniatura quando a matéria não traz imagem.
  String get themeInitial =>
      themeLabel.isEmpty ? '?' : themeLabel[0].toUpperCase();
}
