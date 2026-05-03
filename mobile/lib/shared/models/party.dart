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
    final party = json['party'] as String? ?? '';
    final spectrum = json['spectrum'] as String?;

    return Party(
      id: json['id'] as String,
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
          'Defende maior presença do Estado na economia, fortalecimento de políticas sociais, valorização do salário mínimo e investimentos públicos.',
      'PL':
          'Defende pautas conservadoras, segurança pública, redução do tamanho do Estado e agenda econômica mais liberal.',
      'PDT':
          'Defende um projeto nacional-desenvolvimentista, com investimento em educação, indústria, trabalho e soberania econômica.',
      'MDB':
          'Defende uma linha de centro, com conciliação política, responsabilidade fiscal e manutenção de programas sociais.',
      'UNIAO':
          'Defende uma agenda de centro-direita, com eficiência do Estado, parcerias com o setor privado e foco em segurança e gestão.',
      'NOVO':
          'Defende liberalismo econômico, privatizações, redução de impostos, responsabilidade fiscal e menor intervenção estatal.',
      'PROS':
          'Defende empreendedorismo, desenvolvimento econômico, programas sociais focalizados e ampliação de oportunidades.',
      'PTB':
          'Defende pautas conservadoras, livre iniciativa, redução da intervenção estatal e valores tradicionais.',
      'PCB':
          'Defende ruptura com o modelo capitalista, estatizações, direitos trabalhistas amplos e organização popular.',
      'UP':
          'Defende reformas populares, combate à desigualdade, direitos sociais e maior controle público sobre setores estratégicos.',
      'PSTU':
          'Defende uma agenda socialista, estatização de grandes empresas, direitos trabalhistas e ruptura com políticas de austeridade.',
      'DC':
          'Defende valores democrata-cristãos, família, economia social de mercado e políticas públicas com base comunitária.',
    };

    return summaries[abbreviation] ??
        'Defende propostas ligadas ao campo ${spectrum ?? 'político'} e ao programa apresentado para a eleição.';
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
