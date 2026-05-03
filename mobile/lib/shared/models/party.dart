class Party {
  final String id;
  final String name;
  final String abbreviation;
  final String description;
  final String logoAsset;
  final bool hasLogoAsset;

  const Party({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.description,
    required this.logoAsset,
    required this.hasLogoAsset,
  });

  factory Party.fromCandidateJson(Map<String, dynamic> json) {
    final party = json['party_acronym'] as String;
    final spectrum = json['spectrum'] as String?;

    return Party(
      id: (json['id'] as int).toString(),
      name: json['name'] as String,
      abbreviation: partyAbbreviation(party),
      description: platformSummary(party, spectrum),
      logoAsset: logoAssetForParty(party),
      hasLogoAsset: hasLogoAssetForParty(party),
    );
  }

  static String platformSummary(String party, String? spectrum) {
    final abbreviation = partyAbbreviation(party);
    const summaries = {
      'PT':
          'Defende maior presenca do Estado na economia, fortalecimento de politicas sociais, valorizacao do salario minimo e investimentos publicos.',
      'PL':
          'Defende pautas conservadoras, seguranca publica, reducao do tamanho do Estado e agenda economica mais liberal.',
      'PDT':
          'Defende um projeto nacional-desenvolvimentista, com investimento em educacao, industria, trabalho e soberania economica.',
      'MDB':
          'Defende uma linha de centro, com conciliacao politica, responsabilidade fiscal e manutencao de programas sociais.',
      'UNIAO':
          'Defende uma agenda de centro-direita, com eficiencia do Estado, parcerias com o setor privado e foco em seguranca e gestao.',
      'NOVO':
          'Defende liberalismo economico, privatizacoes, reducao de impostos, responsabilidade fiscal e menor intervencao estatal.',
      'PROS':
          'Defende empreendedorismo, desenvolvimento economico, programas sociais focalizados e ampliacao de oportunidades.',
      'PTB':
          'Defende pautas conservadoras, livre iniciativa, reducao da intervencao estatal e valores tradicionais.',
      'PCB':
          'Defende ruptura com o modelo capitalista, estatizacoes, direitos trabalhistas amplos e organizacao popular.',
      'UP':
          'Defende reformas populares, combate a desigualdade, direitos sociais e maior controle publico sobre setores estrategicos.',
      'PSTU':
          'Defende uma agenda socialista, estatizacao de grandes empresas, direitos trabalhistas e ruptura com politicas de austeridade.',
      'DC':
          'Defende valores democrata-cristaos, familia, economia social de mercado e politicas publicas com base comunitaria.',
    };

    return summaries[abbreviation] ??
        'Defende propostas ligadas ao campo ${spectrum ?? 'politico'} e ao programa apresentado para a eleicao.';
  }

  static String partyAbbreviation(String party) {
    if (party.startsWith('Uni')) return 'UNIAO';
    if (party == 'Novo') return 'NOVO';
    if (party == 'Progressistas') return 'PP';
    return party.toUpperCase();
  }

  static String logoAssetForParty(String party) {
    return 'assets/logos/${partyAbbreviation(party)}.png';
  }

  static bool hasLogoAssetForParty(String party) {
    const available = {
      'AGIR',
      'AVANTE',
      'CIDADANIA',
      'DC',
      'DEMOCRATA',
      'MDB',
      'MISSAO',
      'MOBILIZA',
      'NOVO',
      'PCB',
      'PCdoB',
      'PCO',
      'PDT',
      'PL',
      'PODE',
      'PP',
      'PRD',
      'PROS',
      'PRTB',
      'PSB',
      'PSD',
      'PSDB',
      'PSOL',
      'PSTU',
      'PT',
      'PTB',
      'PV',
      'REDE',
      'REPUBLICANOS',
      'SOLIDARIEDADE',
      'UNIAO',
      'UP',
    };
    return available.contains(partyAbbreviation(party));
  }
}
