import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/quiz_config.dart';
import '../modelos/partido.dart';
import '../modelos/pergunta.dart';
import '../modelos/resposta_quiz.dart';
import '../modelos/resultado_quiz.dart';
import 'api_media_resolver.dart';
import 'partido_catalogo.dart';

class QuizService {
  static const String mensagemErroPadrao =
      'Nao foi possivel carregar os dados. Verifique sua conexao e tente novamente.';
  static const Duration _timeout = Duration(seconds: 10);

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const ApiMediaResolver _mediaResolver = ApiMediaResolver(baseUrl);
  static const PartidoCatalogo _partidoCatalogo =
      PartidoCatalogo(_mediaResolver);

  static String? resolverUrlMidia(String? url) {
    return _mediaResolver.resolver(url);
  }

  static String resolverUrlLogoPartido(String partido) {
    return _partidoCatalogo.resolverUrlLogo(partido);
  }

  Future<List<Pergunta>> buscarPerguntas() async {
    final data = await _getJson(
      '$baseUrl/quiz/questions?limit=${QuizConfig.totalPerguntas}',
    );
    final lista = data['theses'];
    if (lista is! List) {
      throw Exception(mensagemErroPadrao);
    }

    return lista.map((item) => Pergunta.fromJson(item)).toList();
  }

  Future<List<Partido>> buscarPartidos() async {
    final Map<String, Partido> partidos = {};
    var pagina = 1;
    var temProxima = true;

    while (temProxima) {
      final data =
          await _getJson('$baseUrl/candidates?page=$pagina&page_size=50');
      final lista = data['candidates'];
      if (lista is! List) {
        throw Exception(mensagemErroPadrao);
      }

      for (final item in lista) {
        final sigla = (item['party'] ?? '').toString().trim();

        if (sigla.isEmpty || partidos.containsKey(sigla)) continue;
        if (_partidoCatalogo.estaOculto(sigla)) continue;

        partidos[sigla] = _partidoCatalogo.criar(
          sigla,
          logoUrl: item['party_logo']?.toString(),
        );
      }

      temProxima = data['has_next'] == true;
      pagina++;
    }

    final lista = partidos.values.toList();
    lista.sort((a, b) => a.sigla.compareTo(b.sigla));
    return lista;
  }

  Future<List<ResultadoQuiz>> enviarRespostas(
    List<RespostaQuiz> respostas,
    Set<String> partidosSelecionados,
  ) async {
    final data = await _postJson(
      '$baseUrl/quiz/submit',
      {
        'answers': respostas.map((resposta) => resposta.toJson()).toList(),
      },
    );
    final lista = data['results'];
    if (lista is! List) {
      throw Exception(mensagemErroPadrao);
    }

    final resultados = lista.map((item) => ResultadoQuiz.fromJson(item)).where(
      (resultado) {
        if (_partidoCatalogo.estaOculto(resultado.party)) return false;

        return partidosSelecionados.isEmpty ||
            partidosSelecionados.contains(resultado.party);
      },
    ).toList();

    resultados.sort((a, b) => a.rank.compareTo(b.rank));

    return List.generate(
      resultados.length,
      (index) => resultados[index].copyWith(rank: index + 1),
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      return _decodeResponse(response);
    } catch (_) {
      throw Exception(mensagemErroPadrao);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return _decodeResponse(response);
    } catch (_) {
      throw Exception(mensagemErroPadrao);
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(mensagemErroPadrao);
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception(mensagemErroPadrao);
    }

    return data;
  }
}
