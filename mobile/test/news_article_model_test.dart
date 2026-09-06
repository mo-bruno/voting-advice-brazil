import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/news_article.dart';

void main() {
  const json = <String, dynamic>{
    'id': 'abc123',
    'title': 'Eleições 2026: conheça as regras',
    'summary': 'Manual traz orientações sobre propaganda.',
    'image_url': 'https://www.camara.leg.br/foto.jpg',
    'theme_slug': 'eleicoes',
    'theme_label': 'ELEIÇÕES',
    'published_at': '2026-09-04T12:49:00Z',
    'reading_minutes': 2,
    'url': 'https://www.camara.leg.br/noticias/1302574-regras',
  };

  test('converte o json completo', () {
    final article = NewsArticle.fromJson(json);

    expect(article.id, 'abc123');
    expect(article.title, 'Eleições 2026: conheça as regras');
    expect(article.imageUrl, 'https://www.camara.leg.br/foto.jpg');
    expect(article.themeLabel, 'ELEIÇÕES');
    expect(article.readingMinutes, 2);
    expect(article.publishedAt.toUtc().year, 2026);
    expect(article.publishedAt.toUtc().month, 9);
  });

  test('aceita image_url nulo', () {
    final article = NewsArticle.fromJson({...json, 'image_url': null});

    expect(article.imageUrl, isNull);
  });

  test('formata a data no padrao da tela', () {
    final article = NewsArticle.fromJson(json);

    expect(article.formattedDate, matches(r'^\d{2} DE [A-Z]{3}\. DE 2026$'));
  });

  test('formata o tempo de leitura', () {
    final article = NewsArticle.fromJson(json);

    expect(article.readingLabel, '2 MIN DE LEITURA');
  });

  test('inicial do tema serve de fallback quando nao ha imagem', () {
    final article = NewsArticle.fromJson({...json, 'image_url': null});

    expect(article.themeInitial, 'E');
  });

  test('tolera campos opcionais ausentes', () {
    final article = NewsArticle.fromJson({
      'id': 'x',
      'title': 'T',
      'published_at': '2026-09-04T12:49:00Z',
      'url': 'https://example.org/x',
    });

    expect(article.summary, '');
    expect(article.readingMinutes, 1);
    expect(article.themeInitial, '?');
  });
}
