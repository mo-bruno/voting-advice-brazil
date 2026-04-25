class Partido {
  final String sigla;
  final String nome;
  final String descricao;
  final String? logoUrl;

  const Partido({
    required this.sigla,
    required this.nome,
    required this.descricao,
    this.logoUrl,
  });
}
