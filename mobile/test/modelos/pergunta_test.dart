import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/modelos/pergunta.dart';

void main() {
  test('cria pergunta convertendo campos numericos com seguranca', () {
    final pergunta = Pergunta.fromJson({
      'id': '42',
      'text': 'Texto da pergunta',
      'theme_id': 'economia',
      'theme_name': 'Economia',
      'coverage': 0.75,
    });

    expect(pergunta.id, 42);
    expect(pergunta.texto, 'Texto da pergunta');
    expect(pergunta.temaId, 'economia');
    expect(pergunta.temaNome, 'Economia');
    expect(pergunta.coverage, 0.75);
  });

  test('usa valores padrao para campos opcionais ausentes', () {
    final pergunta = Pergunta.fromJson({'id': 1});

    expect(pergunta.id, 1);
    expect(pergunta.texto, isEmpty);
    expect(pergunta.temaId, isNull);
    expect(pergunta.temaNome, isNull);
    expect(pergunta.coverage, isNull);
  });
}
