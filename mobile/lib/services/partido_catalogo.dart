import '../modelos/partido.dart';
import 'api_media_resolver.dart';

class PartidoCatalogo {
  static const Set<String> partidosOcultos = {'PROS', 'PTB'};

  final ApiMediaResolver _mediaResolver;

  const PartidoCatalogo(this._mediaResolver);

  Partido criar(String sigla, {String? logoUrl}) {
    return Partido(
      sigla: sigla,
      nome: nome(sigla),
      descricao: descricao(sigla),
      logoUrl: _mediaResolver.resolver(logoUrl),
      logoUrlSecundaria: resolverUrlLogo(sigla),
    );
  }

  bool estaOculto(String partido) {
    return partidosOcultos.contains(codigo(partido));
  }

  String resolverUrlLogo(String partido) {
    return _mediaResolver.resolver(
      '/static/logos/partidos/${arquivoLogo(partido)}.png',
    )!;
  }

  static String codigo(String partido) {
    return arquivoLogo(partido).toUpperCase();
  }

  static String arquivoLogo(String partido) {
    final normalizado = partido
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (normalizado == 'PARTIDONOVO' || normalizado == 'NOVO') {
      return 'NOVO';
    }
    if (normalizado == 'UNIAOBRASIL' || normalizado == 'UNIAO') {
      return 'UNIAO';
    }
    if (normalizado == 'PCDOB') {
      return 'PCdoB';
    }

    return normalizado;
  }

  static String nome(String partido) {
    const nomes = {
      'DC': 'Democracia Cristã',
      'MDB': 'Movimento Democrático Brasileiro',
      'NOVO': 'Partido Novo',
      'PCDOB': 'Partido Comunista do Brasil',
      'PCB': 'Partido Comunista Brasileiro',
      'PDT': 'Partido Democrático Trabalhista',
      'PL': 'Partido Liberal',
      'PROS': 'Partido Republicano da Ordem Social',
      'PSTU': 'Partido Socialista dos Trabalhadores Unificado',
      'PT': 'Partido dos Trabalhadores',
      'PTB': 'Partido Trabalhista Brasileiro',
      'UP': 'Unidade Popular',
      'UNIAO': 'União Brasil',
      'UNIAOBRASIL': 'União Brasil',
    };

    return nomes[codigo(partido)] ?? partido;
  }

  static String descricao(String partido) {
    const descricoes = {
      'DC':
          'Partido de inspiração democrata-cristã, com ênfase em valores conservadores, família e participação comunitária.',
      'MDB':
          'Partido de centro, com forte presença regional e histórico de participação em governos de diferentes orientações.',
      'NOVO':
          'Partido liberal, associado à defesa de gestão pública enxuta, responsabilidade fiscal e maior espaço para a iniciativa privada.',
      'PCDOB':
          'Partido de esquerda, com origem comunista, que defende políticas sociais, direitos trabalhistas e soberania nacional.',
      'PCB':
          'Partido comunista de esquerda, voltado a pautas socialistas, organização popular e crítica ao modelo econômico liberal.',
      'PDT':
          'Partido trabalhista, ligado ao legado de desenvolvimento nacional, educação pública e proteção de direitos sociais.',
      'PL':
          'Partido de direita, com presença conservadora e liberal em temas econômicos, segurança e costumes.',
      'PROS':
          'Partido de perfil pragmático, historicamente formado por alianças regionais e atuação em pautas sociais variadas.',
      'PSTU':
          'Partido de esquerda socialista, com foco em trabalhadores, movimentos sociais e oposição ao capitalismo.',
      'PT':
          'Partido de esquerda, associado a políticas sociais, inclusão, direitos trabalhistas e maior atuação do Estado.',
      'PTB':
          'Partido trabalhista tradicional, com atuação variável ao longo do tempo e presença em diferentes campos políticos.',
      'UP':
          'Partido de esquerda popular, ligado a movimentos sociais, moradia, trabalho e organização de base.',
      'UNIAO':
          'Partido de centro-direita formado pela fusão entre DEM e PSL, com atuação ampla em economia, gestão e segurança.',
      'UNIAOBRASIL':
          'Partido de centro-direita formado pela fusão entre DEM e PSL, com atuação ampla em economia, gestão e segurança.',
    };

    return descricoes[codigo(partido)] ??
        'Partido incluído na comparação dos resultados do quiz.';
  }
}
