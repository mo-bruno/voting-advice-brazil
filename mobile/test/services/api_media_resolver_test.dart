import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/services/api_media_resolver.dart';
import 'package:guia_eleitoral/services/partido_catalogo.dart';

void main() {
  const resolver = ApiMediaResolver('http://localhost:8000/api/v1');

  test('mantem URL absoluta sem alterar', () {
    expect(
      resolver.resolver('https://example.com/logo.png'),
      'https://example.com/logo.png',
    );
  });

  test('converte caminho data para rota publica estatica', () {
    expect(
      resolver.resolver('data/logos/partidos/PT.png'),
      'http://localhost:8000/static/logos/partidos/PT.png',
    );
  });

  test('monta URL calculada do logo do partido', () {
    const catalogo = PartidoCatalogo(resolver);

    expect(
      catalogo.resolverUrlLogo('Uniao Brasil'),
      'http://localhost:8000/static/logos/partidos/UNIAO.png',
    );
  });
}
