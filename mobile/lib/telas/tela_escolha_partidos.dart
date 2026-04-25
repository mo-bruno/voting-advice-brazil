import 'package:flutter/material.dart';

import '../modelos/partido.dart';
import '../modelos/resposta_quiz.dart';
import '../services/quiz_service.dart';
import '../widgets/partidos/conteudo_escolha_partidos.dart';
import '../widgets/partidos/dialog_detalhe_partido.dart';
import '../widgets/partidos/rodape_escolha_partidos.dart';
import '../widgets/topo_padrao.dart';
import 'tela_resultado_quiz.dart';

class TelaEscolhaPartidos extends StatefulWidget {
  final List<RespostaQuiz> respostas;

  const TelaEscolhaPartidos({
    super.key,
    required this.respostas,
  });

  @override
  State<TelaEscolhaPartidos> createState() => _TelaEscolhaPartidosState();
}

class _TelaEscolhaPartidosState extends State<TelaEscolhaPartidos> {
  final QuizService _service = QuizService();
  final Set<String> _selecionados = {};

  List<Partido> _partidos = [];
  bool _carregando = true;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarPartidos();
  }

  Future<void> _carregarPartidos() async {
    try {
      final partidos = await _service.buscarPartidos();

      if (!mounted) return;

      setState(() {
        _partidos = partidos;
        _selecionados.addAll(partidos.map((partido) => partido.sigla));
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

  void _alternarTodos() {
    setState(() {
      if (_selecionados.length == _partidos.length) {
        _selecionados.clear();
      } else {
        _selecionados
          ..clear()
          ..addAll(_partidos.map((partido) => partido.sigla));
      }
    });
  }

  void _alternarPartido(String sigla) {
    setState(() {
      if (_selecionados.contains(sigla)) {
        _selecionados.remove(sigla);
      } else {
        _selecionados.add(sigla);
      }
    });
  }

  void _mostrarDetalhe(Partido partido) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => DialogDetalhePartido(partido: partido),
    );
  }

  Future<void> _continuar() async {
    if (_selecionados.isEmpty) return;

    setState(() {
      _enviando = true;
    });

    try {
      final resultados = await _service.enviarRespostas(
        widget.respostas,
        _selecionados,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => TelaResultadoQuiz(
            resultados: resultados,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

      if (!mounted) return;

      setState(() {
        _enviando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _enviando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao calcular resultado: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeContinuar = _selecionados.isNotEmpty && !_enviando;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(
              mostrarVoltar: true,
              titulo: 'Escolha os partidos',
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth > 900;
                  final larguraMaxima = telaGrande ? 760.0 : 430.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: larguraMaxima),
                      child: ConteudoEscolhaPartidos(
                        carregando: _carregando,
                        erro: _erro,
                        partidos: _partidos,
                        selecionados: _selecionados,
                        telaGrande: telaGrande,
                        onAlternarTodos: _alternarTodos,
                        onAlternarPartido: _alternarPartido,
                        onMostrarDetalhe: _mostrarDetalhe,
                      ),
                    ),
                  );
                },
              ),
            ),
            RodapeEscolhaPartidos(
              enviando: _enviando,
              podeContinuar: podeContinuar,
              selecionados: _selecionados.length,
              total: _partidos.length,
              onContinuar: _continuar,
            ),
          ],
        ),
      ),
    );
  }
}
