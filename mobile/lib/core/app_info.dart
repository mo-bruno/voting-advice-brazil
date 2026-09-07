// lib/core/app_info.dart
//
// Identidade da build exibida ao usuario. E uma constante, e nao um
// package_info_plus, porque a unica coisa que o app precisa saber sobre si
// mesmo hoje e a versao no rodape da gaveta — nao vale uma dependencia com
// configuracao por plataforma. `drawer_chrome_test.dart` le o pubspec e falha
// se as duas se separarem.

const String kAppVersion = '1.0.0';
