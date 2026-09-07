import 'package:url_launcher/url_launcher.dart';

/// Assinatura de quem abre uma URL externa.
///
/// Existe para que a tela receba a função por parâmetro e o teste de widget
/// possa substituí-la — chamar `url_launcher` direto num teste exigiria o
/// plugin, que não roda em `flutter test`.
typedef LinkOpener = Future<bool> Function(Uri url);

Future<bool> openExternalLink(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}
