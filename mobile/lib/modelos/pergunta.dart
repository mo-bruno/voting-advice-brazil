class Pergunta {
  final int id;
  final String texto;
  final String? temaId;
  final String? temaNome;
  final double? coverage;

  const Pergunta({
    required this.id,
    required this.texto,
    this.temaId,
    this.temaNome,
    this.coverage,
  });

  factory Pergunta.fromJson(Map<String, dynamic> json) {
    return Pergunta(
      id: json['id'],
      texto: json['text'],
      temaId: json['theme_id'],
      temaNome: json['theme_name'],
      coverage: (json['coverage'] as num?)?.toDouble(),
    );
  }
}
