class Party {
  final String id;
  final String name;
  final String abbreviation;
  final String description;
  final String logoAsset;
  final bool hasLogoAsset;
  final String? photoUrl;
  final String? officialStatus;
  final String? sourceSnapshot;

  const Party({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.description,
    required this.logoAsset,
    required this.hasLogoAsset,
    this.photoUrl,
    this.officialStatus,
    this.sourceSnapshot,
  });

  factory Party.fromCandidateJson(Map<String, dynamic> json) {
    final party = json['party_acronym'] as String;

    return Party(
      id: (json['id'] as int).toString(),
      name: json['name'] as String,
      abbreviation: partyAbbreviation(party),
      description:
          'As posições exibidas na comparação vêm exclusivamente do plano oficial de governo desta candidatura.',
      logoAsset: logoAssetForParty(party),
      hasLogoAsset: hasLogoAssetForParty(party),
      photoUrl: json['photo_url'] as String?,
      officialStatus: json['official_status'] as String?,
      sourceSnapshot: json['source_snapshot'] as String?,
    );
  }

  static String partyAbbreviation(String party) {
    var normalized = party.trim().toUpperCase();
    const replacements = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'É': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ç': 'C',
    };
    replacements.forEach((accented, ascii) {
      normalized = normalized.replaceAll(accented, ascii);
    });
    if (normalized.startsWith('UNIAO')) return 'UNIAO';
    if (normalized == 'PROGRESSISTAS') return 'PP';
    if (normalized == 'PCDOB' || normalized == 'PC DO B') return 'PCdoB';
    return normalized;
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
