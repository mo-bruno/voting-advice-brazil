import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/followed_actor_tile.dart';

void main() {
  setUp(() {});

  PoliticalActor actor({String? party = 'PDT', String? state = 'RS'}) {
    return PoliticalActor(
      id: 7,
      source: 'camara',
      sourceId: '204554',
      displayName: 'Ana Vasconcelos',
      party: party,
      state: state,
      role: 'federal_deputy',
      status: 'active',
      photoUrl: 'https://exemplo.test/foto.jpg',
      sourceUrl: null,
      lastIndexedAt: DateTime.utc(2026, 3, 1),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    PoliticalActor? followed,
    VoidCallback? onOpenProfile,
    VoidCallback? onChoose,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          width: 304,
          child: FollowedActorTile(
            actor: followed,
            onOpenProfile: onOpenProfile ?? () {},
            onChoose: onChoose ?? () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('sempre se identifica, com ou sem alguem seguido',
      (tester) async {
    await pump(tester);

    expect(find.text('ACOMPANHANDO'), findsOneWidget);
  });

  group('com alguem seguido', () {
    testWidgets('mostra nome, partido, UF e cargo', (tester) async {
      await pump(tester, followed: actor());

      expect(find.text('Ana Vasconcelos'), findsOneWidget);
      expect(find.text('PDT • RS · Deputada(o) federal'), findsOneWidget);
    });

    testWidgets('a foto e substituida pelas iniciais do nome', (tester) async {
      // A gaveta nao carrega imagem de rede: um avatar em branco enquanto baixa
      // e pior do que duas letras que aparecem na hora.
      await pump(tester, followed: actor());

      expect(find.text('AV'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('omite o que a Camara nao informou', (tester) async {
      await pump(tester, followed: actor(party: null, state: null));

      expect(find.text('Deputada(o) federal'), findsOneWidget);
    });

    testWidgets('tocar abre o perfil', (tester) async {
      var abriu = 0;
      await pump(
        tester,
        followed: actor(),
        onOpenProfile: () => abriu++,
      );

      await tester.tap(find.text('Ana Vasconcelos'));
      await tester.pump();

      expect(abriu, 1);
    });
  });

  group('sem ninguem seguido', () {
    testWidgets('convida a escolher em vez de sumir', (tester) async {
      await pump(tester);

      expect(find.text('Você ainda não segue ninguém.'), findsOneWidget);
      expect(find.text('Escolher um político'), findsOneWidget);
    });

    testWidgets('o convite leva a busca, nao ao perfil', (tester) async {
      var escolheu = 0;
      var abriu = 0;
      await pump(
        tester,
        onChoose: () => escolheu++,
        onOpenProfile: () => abriu++,
      );

      await tester.tap(find.text('Escolher um político'));
      await tester.pump();

      expect(escolheu, 1);
      expect(abriu, 0);
    });
  });
}
