/// Um tema do quiz, reutilizado como categoria opcional de post.
///
/// Nome proprio para nao colidir com o `Theme` do Flutter, que qualquer arquivo
/// de UI importa junto com o material.dart.
class CommunityTheme {
  const CommunityTheme({required this.slug, required this.nome});

  final String slug;
  final String nome;

  factory CommunityTheme.fromJson(Map<String, dynamic> json) => CommunityTheme(
        slug: json['slug'] as String,
        nome: json['nome'] as String,
      );
}
