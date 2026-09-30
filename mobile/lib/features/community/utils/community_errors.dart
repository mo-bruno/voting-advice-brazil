import '../../../core/api/api_client.dart';

String communityErrorMessage(Object error, {required String fallback}) {
  if (error is! ApiException) return fallback;
  switch (error.statusCode) {
    case 422:
      return error.message.trim().isNotEmpty
          ? error.message
          : 'O conteúdo não foi aceito. Revise o texto e tente novamente.';
    case 429:
      final seconds = error.retryAfterSeconds;
      final wait = seconds != null && seconds > 0
          ? 'Aguarde ${(seconds / 60).ceil()} minuto${seconds > 60 ? 's' : ''}'
          : 'Aguarde alguns minutos';
      return 'Você atingiu o limite de envios. $wait e tente novamente.';
    case 503:
      return 'A moderação está temporariamente indisponível. '
          'Seu texto foi mantido; tente novamente em instantes.';
    case 404:
      return 'O conteúdo não foi encontrado.';
    case 410:
      return 'Este post foi removido. Não é possível votar ou comentar.';
    case 403:
    case 408:
      return error.message;
    default:
      return fallback;
  }
}
