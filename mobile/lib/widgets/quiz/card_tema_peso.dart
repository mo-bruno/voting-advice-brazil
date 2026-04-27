import 'package:flutter/material.dart';
import '../../modelos/pergunta.dart';
import '../../modelos/resposta_quiz.dart';
import 'editor_resposta_tema.dart';

class CardTemaPeso extends StatelessWidget {
  final int numero;
  final Pergunta pergunta;
  final String? resposta;
  final bool marcado;
  final bool editando;
  final VoidCallback onAlternarPeso;
  final VoidCallback onAlternarEdicao;
  final ValueChanged<String> onAlterarResposta;

  const CardTemaPeso({
    super.key,
    required this.numero,
    required this.pergunta,
    required this.resposta,
    required this.marcado,
    required this.editando,
    required this.onAlternarPeso,
    required this.onAlternarEdicao,
    required this.onAlterarResposta,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: marcado ? const Color(0xFF2B2B2B) : const Color(0xFF202020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: editando || marcado ? Colors.white : const Color(0xFF3A3A3A),
          width: editando || marcado ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TextoTema(
                    numero: numero,
                    pergunta: pergunta,
                    resposta: resposta,
                  ),
                ),
                const SizedBox(width: 16),
                _AcoesTema(
                  marcado: marcado,
                  editando: editando,
                  onAlternarPeso: onAlternarPeso,
                  onAlternarEdicao: onAlternarEdicao,
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: editando
                  ? EditorRespostaTema(
                      key: const ValueKey('editor'),
                      respostaAtual: resposta,
                      onAlterarResposta: onAlterarResposta,
                    )
                  : const SizedBox.shrink(key: ValueKey('fechado')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextoTema extends StatelessWidget {
  final int numero;
  final Pergunta pergunta;
  final String? resposta;

  const _TextoTema({
    required this.numero,
    required this.pergunta,
    required this.resposta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEMA $numero',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pergunta.texto,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sua resposta: ${RespostaQuizValor.texto(resposta)}',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AcoesTema extends StatelessWidget {
  final bool marcado;
  final bool editando;
  final VoidCallback onAlternarPeso;
  final VoidCallback onAlternarEdicao;

  const _AcoesTema({
    required this.marcado,
    required this.editando,
    required this.onAlternarPeso,
    required this.onAlternarEdicao,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: editando ? 'Fechar edição' : 'Editar resposta',
          onPressed: onAlternarEdicao,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            backgroundColor: editando ? Colors.white : const Color(0xFF111111),
            side: BorderSide(
              color: editando ? Colors.white : Colors.white24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            editando ? Icons.close_rounded : Icons.edit_rounded,
            color: editando ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onAlternarPeso,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: marcado ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: marcado ? Colors.white : Colors.white24,
                width: 1.2,
              ),
            ),
            child: Text(
              'x2',
              style: TextStyle(
                color: marcado ? Colors.black : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
