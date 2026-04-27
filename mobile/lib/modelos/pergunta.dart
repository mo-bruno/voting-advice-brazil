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
    final id = json['id'];
    final coverage = json['coverage'];

    return Pergunta(
      id: id is num ? id.toInt() : int.parse(id.toString()),
      texto: json['text'] as String? ?? '',
      temaId: json['theme_id'] as String?,
      temaNome: json['theme_name'] as String?,
      coverage: coverage is num ? coverage.toDouble() : null,
    );
  }
}
