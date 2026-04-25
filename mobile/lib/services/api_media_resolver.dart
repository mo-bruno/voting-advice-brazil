class ApiMediaResolver {
  final String baseUrl;

  const ApiMediaResolver(this.baseUrl);

  String? resolver(String? url) {
    if (url == null || url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) return url;

    final apiUri = Uri.parse(baseUrl);
    final origem = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString();

    if (url.startsWith('/')) {
      return '$origem$url';
    }

    return '$origem/$url';
  }
}
