import 'package:flutter/material.dart';
import '../modelos/pergunta.dart';
import '../modelos/resposta_quiz.dart';
import '../routes/app_routes.dart';
import '../services/quiz_service.dart';
import '../widgets/topo_padrao.dart';

class TelaPerguntaQuiz extends StatefulWidget {
  const TelaPerguntaQuiz({super.key});

  @override
  State<TelaPerguntaQuiz> createState() => _TelaPerguntaQuizState();
}

class _TelaPerguntaQuizState extends State<TelaPerguntaQuiz> {
  final QuizService service = QuizService();

  List<Pergunta> perguntas = [];
  final Map<int, String> respostas = {};
  final Set<int> pesosDuplos = {};

  int indiceAtual = 0;
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregarPerguntas();
  }

  Future<void> carregarPerguntas() async {
    try {
      final lista = await service.buscarPerguntas();

      setState(() {
        perguntas = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString();
        carregando = false;
      });
    }
  }

  void responder(String answer) {
    final pergunta = perguntas[indiceAtual];

    respostas[pergunta.id] = answer;

    if (indiceAtual < perguntas.length - 1) {
      setState(() {
        indiceAtual++;
      });
    } else {
      Navigator.pushNamed(
        context,
        AppRoutes.revisaoRespostas,
        arguments: RevisaoRespostasArgs(
          perguntas: perguntas,
          respostas: respostas,
          pesosDuplos: pesosDuplos,
          onPesosAlterados: atualizarPesos,
        ),
      );
    }
  }

  void atualizarPesos(Set<int> novosPesosDuplos) {
    pesosDuplos
      ..clear()
      ..addAll(novosPesosDuplos);
  }

  void voltarPergunta() {
    if (indiceAtual > 0) {
      setState(() {
        indiceAtual--;
      });
    }
  }

  void voltarTelaAnterior() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (erro != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              TopoPadrao(
                mostrarVoltar: true,
                onVoltar: voltarTelaAnterior,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      erro!,
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

    final pergunta = perguntas[indiceAtual];
    final numeroPergunta = indiceAtual + 1;
    final totalPerguntas = perguntas.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopoPadrao(
              mostrarVoltar: true,
              onVoltar: voltarTelaAnterior,
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
                            if (indiceAtual > 0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: voltarPergunta,
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Voltar pergunta',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0D),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Text(
                                      '$numeroPergunta/$totalPerguntas',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  SizedBox(
                                    height: telaGrande ? 220 : 180,
                                    child: Center(
                                      child: Text(
                                        pergunta.texto,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: telaGrande ? 24 : 20,
                                          height: 1.45,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _BotaoAcaoQuiz(
                                        icone: Icons.close_rounded,
                                        onTap: () => responder(
                                          RespostaQuizValor.discordo,
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      _BotaoAcaoQuiz(
                                        icone: Icons.remove_rounded,
                                        onTap: () => responder(
                                          RespostaQuizValor.neutro,
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      _BotaoAcaoQuiz(
                                        icone: Icons.check_rounded,
                                        onTap: () => responder(
                                          RespostaQuizValor.concordo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _IndicadorProgressoLinear(
                              total: totalPerguntas,
                              atual: indiceAtual,
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

class _IndicadorProgressoLinear extends StatelessWidget {
  final int total;
  final int atual;

  const _IndicadorProgressoLinear({
    required this.total,
    required this.atual,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisiveis = 11;

    int inicio = atual - (maxVisiveis ~/ 2);
    if (inicio < 0) inicio = 0;

    int fim = inicio + maxVisiveis;
    if (fim > total) {
      fim = total;
      inicio = fim - maxVisiveis;
      if (inicio < 0) inicio = 0;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(fim - inicio, (i) {
        final index = inicio + i;
        final selecionado = index == atual;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selecionado ? 18 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: selecionado ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionado ? Colors.white : Colors.white38,
            ),
          ),
        );
      }),
    );
  }
}

class _BotaoAcaoQuiz extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;

  const _BotaoAcaoQuiz({
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(
          icone,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
