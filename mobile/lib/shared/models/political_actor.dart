class PoliticalActor {
  final int id;
  final String source;
  final String sourceId;
  final String displayName;
  final String? party;
  final String? state;
  final String role;
  final String status;
  final String? photoUrl;
  final String? sourceUrl;
  final DateTime lastIndexedAt;

  const PoliticalActor({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.displayName,
    required this.party,
    required this.state,
    required this.role,
    required this.status,
    required this.photoUrl,
    required this.sourceUrl,
    required this.lastIndexedAt,
  });

  factory PoliticalActor.fromJson(Map<String, dynamic> json) {
    return PoliticalActor(
      id: json['id'] as int,
      source: json['source'] as String,
      sourceId: json['source_id'] as String,
      displayName: json['display_name'] as String,
      party: json['party'] as String?,
      state: json['state'] as String?,
      role: json['role'] as String,
      status: json['status'] as String,
      photoUrl: json['photo_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      lastIndexedAt: DateTime.parse(json['last_indexed_at'] as String),
    );
  }

  String get roleLabel {
    if (role == 'federal_deputy') return 'Deputada(o) federal';
    return role;
  }
}

class PoliticalActorListResponse {
  final List<PoliticalActor> actors;
  final int totalCount;
  final bool hasNext;

  const PoliticalActorListResponse({
    required this.actors,
    required this.totalCount,
    required this.hasNext,
  });

  factory PoliticalActorListResponse.fromJson(Map<String, dynamic> json) {
    return PoliticalActorListResponse(
      actors: (json['actors'] as List<dynamic>)
          .map((item) => PoliticalActor.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int,
      hasNext: json['has_next'] as bool,
    );
  }
}

class TrendingPoliticalActor {
  final PoliticalActor actor;
  final int rank;

  const TrendingPoliticalActor({required this.actor, required this.rank});

  factory TrendingPoliticalActor.fromJson(Map<String, dynamic> json) {
    return TrendingPoliticalActor(
      actor: PoliticalActor.fromJson(json['actor'] as Map<String, dynamic>),
      rank: json['rank'] as int,
    );
  }
}
