import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';
import 'package:guia_eleitoral/features/community/widgets/post_card.dart';

PostSummary _post({
  bool removed = false,
  String? removedBy,
  String? themeSlug = 'economia',
}) =>
    PostSummary(
      id: 'p1',
      anonymousId: 'a4a91c2f',
      content: removed ? '' : 'Conteudo do post',
      politicalActorId: null,
      themeSlug: themeSlug,
      score: 128,
      createdAt: DateTime.utc(2026, 9, 4),
      removed: removed,
      removedBy: removedBy,
    );

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

void main() {
  testWidgets('mostra voto, autor, conteudo e tema', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(post: _post(), onTap: () {})));

    expect(find.text('128'), findsOneWidget);
    expect(find.text('Conteudo do post'), findsOneWidget);
    expect(find.text('ECONOMIA'), findsOneWidget);
    expect(find.textContaining('u/'), findsOneWidget);
  });

  testWidgets('lapide substitui o conteudo e esconde as setas', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(removed: true, removedBy: 'author'),
      onTap: () {},
    )));

    expect(find.text('Removido pelo autor'), findsOneWidget);
    expect(find.text('Conteudo do post'), findsNothing);
    // Sem setas: votar num post removido nao faz sentido.
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    // O numero permanece: a pontuacao que o post teve continua sendo um fato.
    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('post sem tema nao mostra chip vazio', (tester) async {
    await tester.pumpWidget(
      _wrap(PostCard(post: _post(themeSlug: null), onTap: () {})),
    );

    expect(find.text('ECONOMIA'), findsNothing);
  });

  testWidgets('setas ficam inertes enquanto o voto esta em voo',
      (tester) async {
    var votou = false;
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(),
      onTap: () {},
      votePending: true,
      onVote: (_) => votou = true,
    )));

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();

    expect(votou, isFalse);
  });
}
