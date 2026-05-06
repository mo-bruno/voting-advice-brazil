enum EvidenceType { vote, proposition, expense, other }

class OfficialEvidence {
  final int id;
  final int politicalActorId;
  final String source;
  final String sourceId;
  final EvidenceType type;
  final String title;
  final String summary;
  final DateTime? evidenceDate;
  final String? sourceUrl;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  const OfficialEvidence({
    required this.id,
    required this.politicalActorId,
    required this.source,
    required this.sourceId,
    required this.type,
    required this.title,
    required this.summary,
    required this.evidenceDate,
    required this.sourceUrl,
    required this.fetchedAt,
    required this.expiresAt,
  });

  factory OfficialEvidence.fromJson(Map<String, dynamic> json) {
    return OfficialEvidence(
      id: json['id'] as int,
      politicalActorId: json['political_actor_id'] as int,
      source: json['source'] as String,
      sourceId: json['source_id'] as String,
      type: _typeFromJson(json['evidence_type'] as String),
      title: json['title'] as String,
      summary: json['summary'] as String,
      evidenceDate: json['evidence_date'] == null
          ? null
          : DateTime.parse(json['evidence_date'] as String),
      sourceUrl: json['source_url'] as String?,
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  String get sourceLabel {
    if (source == 'camara') return 'Fonte: Camara dos Deputados';
    return 'Fonte oficial';
  }

  static EvidenceType _typeFromJson(String value) {
    return switch (value) {
      'vote' => EvidenceType.vote,
      'proposition' => EvidenceType.proposition,
      'expense' => EvidenceType.expense,
      _ => EvidenceType.other,
    };
  }
}

class EvidenceResponse {
  final String cacheStatus;
  final List<OfficialEvidence> evidence;

  const EvidenceResponse({required this.cacheStatus, required this.evidence});

  factory EvidenceResponse.fromJson(Map<String, dynamic> json) {
    return EvidenceResponse(
      cacheStatus: json['cache_status'] as String,
      evidence: (json['evidence'] as List<dynamic>)
          .map(
              (item) => OfficialEvidence.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
