import 'thesis.dart';

class Party {
  final String id;
  final String name;
  final String abbreviation;
  final String description;
  final Map<int, ThesisAnswer> positions;

  const Party({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.description,
    required this.positions,
  });

  static List<Party> getSampleParties() {
    return [
      Party(
        id: 'pt',
        name: 'Partido dos Trabalhadores',
        abbreviation: 'PT',
        description: 'O PT é um dos maiores partidos do Brasil. Historicamente ligado a políticas de inclusão social e redistribuição de renda, defende políticas públicas fortes e o papel do Estado na economia.',
        positions: {1: ThesisAnswer.disagree, 2: ThesisAnswer.agree, 3: ThesisAnswer.agree, 4: ThesisAnswer.agree, 5: ThesisAnswer.agree, 6: ThesisAnswer.disagree, 7: ThesisAnswer.agree, 8: ThesisAnswer.neutral, 9: ThesisAnswer.agree, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'psol',
        name: 'Partido Socialismo e Liberdade',
        abbreviation: 'PSOL',
        description: 'Partido de esquerda que defende o socialismo democrático, a ecologia e os direitos das minorias.',
        positions: {1: ThesisAnswer.disagree, 2: ThesisAnswer.agree, 3: ThesisAnswer.agree, 4: ThesisAnswer.agree, 5: ThesisAnswer.agree, 6: ThesisAnswer.disagree, 7: ThesisAnswer.agree, 8: ThesisAnswer.agree, 9: ThesisAnswer.agree, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'psb',
        name: 'Partido Socialista Brasileiro',
        abbreviation: 'PSB',
        description: 'Partido de centro-esquerda que busca conciliar socialismo democrático com modernização.',
        positions: {1: ThesisAnswer.neutral, 2: ThesisAnswer.agree, 3: ThesisAnswer.agree, 4: ThesisAnswer.agree, 5: ThesisAnswer.agree, 6: ThesisAnswer.disagree, 7: ThesisAnswer.agree, 8: ThesisAnswer.neutral, 9: ThesisAnswer.agree, 10: ThesisAnswer.neutral},
      ),
      Party(
        id: 'mdb',
        name: 'Movimento Democrático Brasileiro',
        abbreviation: 'MDB',
        description: 'Partido de centro com ampla base regional, historicamente presente em governos de diferentes orientações.',
        positions: {1: ThesisAnswer.neutral, 2: ThesisAnswer.agree, 3: ThesisAnswer.agree, 4: ThesisAnswer.neutral, 5: ThesisAnswer.agree, 6: ThesisAnswer.neutral, 7: ThesisAnswer.neutral, 8: ThesisAnswer.disagree, 9: ThesisAnswer.neutral, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'novo',
        name: 'Partido Novo',
        abbreviation: 'NOVO',
        description: 'Partido liberal que defende o Estado mínimo, livre mercado e responsabilidade fiscal.',
        positions: {1: ThesisAnswer.agree, 2: ThesisAnswer.disagree, 3: ThesisAnswer.disagree, 4: ThesisAnswer.neutral, 5: ThesisAnswer.agree, 6: ThesisAnswer.agree, 7: ThesisAnswer.disagree, 8: ThesisAnswer.neutral, 9: ThesisAnswer.disagree, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'pl',
        name: 'Partido Liberal',
        abbreviation: 'PL',
        description: 'Partido de direita com forte base conservadora e defesa de valores tradicionais.',
        positions: {1: ThesisAnswer.agree, 2: ThesisAnswer.disagree, 3: ThesisAnswer.disagree, 4: ThesisAnswer.disagree, 5: ThesisAnswer.neutral, 6: ThesisAnswer.agree, 7: ThesisAnswer.disagree, 8: ThesisAnswer.disagree, 9: ThesisAnswer.disagree, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'psd',
        name: 'Partido Social Democrático',
        abbreviation: 'PSD',
        description: 'Partido de centro que busca conciliar desenvolvimento econômico com políticas sociais.',
        positions: {1: ThesisAnswer.neutral, 2: ThesisAnswer.agree, 3: ThesisAnswer.agree, 4: ThesisAnswer.neutral, 5: ThesisAnswer.agree, 6: ThesisAnswer.neutral, 7: ThesisAnswer.neutral, 8: ThesisAnswer.disagree, 9: ThesisAnswer.neutral, 10: ThesisAnswer.agree},
      ),
      Party(
        id: 'pp',
        name: 'Progressistas',
        abbreviation: 'PP',
        description: 'Partido de centro-direita com foco em desenvolvimento e pragmatismo político.',
        positions: {1: ThesisAnswer.agree, 2: ThesisAnswer.neutral, 3: ThesisAnswer.neutral, 4: ThesisAnswer.disagree, 5: ThesisAnswer.agree, 6: ThesisAnswer.agree, 7: ThesisAnswer.disagree, 8: ThesisAnswer.disagree, 9: ThesisAnswer.disagree, 10: ThesisAnswer.agree},
      ),
    ];
  }
}
