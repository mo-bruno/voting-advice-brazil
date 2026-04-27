class ApiMediaResolver {
  final String baseUrl;

  const ApiMediaResolver(this.baseUrl);

  String? resolver(String? url) {
    if (url == null || url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return url;

    final publicUrl = _resolverCaminhoPublico(url);

    final apiUri = Uri.parse(baseUrl);
    final origem = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString();

    if (publicUrl.startsWith('/')) {
      return '$origem$publicUrl';
    }

    return '$origem/$publicUrl';
  }

  String _resolverCaminhoPublico(String url) {
    if (url.startsWith('data/')) {
      return '/static/${url.substring('data/'.length)}';
    }

    return url;
  }
}
