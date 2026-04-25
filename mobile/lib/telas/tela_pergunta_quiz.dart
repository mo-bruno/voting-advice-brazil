import 'package:flutter/material.dart';
import '../modelos/pergunta.dart';
import '../modelos/resposta_quiz.dart';
import '../services/quiz_service.dart';
import '../widgets/quiz/cartao_pergunta_quiz.dart';
import '../widgets/quiz/indicador_progresso_quiz.dart';
import '../widgets/topo_padrao.dart';
import 'tela_revisao_respostas.dart';

class TelaPerguntaQuiz extends StatefulWidget {
  const TelaPerguntaQuiz({super.key});

  @override
  State<TelaPerguntaQuiz> createState() => _TelaPerguntaQuizState();
}

class _TelaPerguntaQuizState extends State<TelaPerguntaQuiz> {
  final QuizService _service = QuizService();
  final Map<int, RespostaQuiz> _respostas = {};
  final Set<int> _pesosDuplos = {};

  List<Pergunta> _perguntas = [];
  int _indiceAtual = 0;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarPerguntas();
  }

  Future<void> _carregarPerguntas() async {
    try {
      final lista = await _service.buscarPerguntas();

      if (!mounted) return;

      setState(() {
        _perguntas = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  void _responder(String answer) {
    final pergunta = _perguntas[_indiceAtual];

    _respostas[pergunta.id] = RespostaQuiz(
      thesisId: pergunta.id,
      answer: answer,
      weight: 1,
    );

    if (_indiceAtual < _perguntas.length - 1) {
      setState(() {
        _indiceAtual++;
      });
      return;
    }

    _abrirRevisao();
  }

  void _abrirRevisao() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TelaRevisaoRespostas(
          perguntas: _perguntas,
          respostas: _respostas,
          pesosDuplos: _pesosDuplos,
          onPesosAlterados: _atualizarPesos,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _atualizarPesos(Set<int> pesosDuplos) {
    _pesosDuplos
      ..clear()
      ..addAll(pesosDuplos);
  }

  void _voltarPergunta() {
    if (_indiceAtual > 0) {
      setState(() {
        _indiceAtual--;
      });
    }
  }

  void _voltarInicio() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_erro != null) {
      return _TelaPerguntaErro(erro: _erro!);
    }

    if (_perguntas.isEmpty) {
      return const _TelaPerguntaErro(
        erro: 'Nenhuma pergunta foi encontrada.',
      );
    }

    final pergunta = _perguntas[_indiceAtual];
    final numeroPergunta = _indiceAtual + 1;
    final totalPerguntas = _perguntas.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopoPadrao(
              mostrarVoltar: true,
              onVoltar: _voltarInicio,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth > 900;
                  final larguraMaxima = telaGrande ? 560.0 : 380.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: telaGrande ? 40 : 24,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: larguraMaxima),
                        child: Column(
                          children: [
                            CartaoPerguntaQuiz(
                              pergunta: pergunta,
                              numeroPergunta: numeroPergunta,
                              totalPerguntas: totalPerguntas,
                              telaGrande: telaGrande,
                              onDiscordar: () => _responder(
                                RespostaQuizValor.discordo,
                              ),
                              onNeutro: () => _responder(
                                RespostaQuizValor.neutro,
                              ),
                              onConcordar: () => _responder(
                                RespostaQuizValor.concordo,
                              ),
                              podeVoltarPergunta: _indiceAtual > 0,
                              onVoltarPergunta: _voltarPergunta,
                            ),
                            const SizedBox(height: 20),
                            IndicadorProgressoQuiz(
                              total: totalPerguntas,
                              atual: _indiceAtual,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelaPerguntaErro extends StatelessWidget {
  final String erro;

  const _TelaPerguntaErro({required this.erro});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(mostrarVoltar: true),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    erro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
