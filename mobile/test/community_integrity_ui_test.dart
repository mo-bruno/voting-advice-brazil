import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';
import 'package:guia_eleitoral/features/community/widgets/post_card.dart';

PostSummary _post({
  String anonymousId = 'autor',
  bool removed = false,
  String? removedBy,
}) =>
    PostSummary(
      id: 'p1',
      anonymousId: anonymousId,
      content: removed ? '' : 'Conteudo visivel',
      politicalActorId: null,
      themeSlug: null,
      score: 3,
      createdAt: DateTime.utc(2026, 9, 4),
      removed: removed,
      removedBy: removedBy,
    );

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

void main() {
  testWidgets('lapide do autor substitui o conteudo', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(removed: true, removedBy: 'author'),
      onTap: () {},
      currentAnonymousId: 'outro',
    )));

    expect(find.text('Removido pelo autor'), findsOneWidget);
    expect(find.text('Conteudo visivel'), findsNothing);
  });

  testWidgets('lapide da moderacao tem rotulo proprio', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(removed: true, removedBy: 'moderation'),
      onTap: () {},
      currentAnonymousId: 'outro',
    )));

    expect(find.text('Removido pela moderação'), findsOneWidget);
  });

  testWidgets('apagar so aparece no post do proprio dispositivo',
      (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(anonymousId: 'eu'),
      onTap: () {},
      currentAnonymousId: 'eu',
      onDelete: () {},
      onReport: () {},
    )));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Apagar'), findsOneWidget);
    expect(find.text('Denunciar'), findsOneWidget);
  });

  testWidgets('post de terceiro nao oferece apagar', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(anonymousId: 'outra-pessoa'),
      onTap: () {},
      currentAnonymousId: 'eu',
      onDelete: () {},
      onReport: () {},
    )));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Apagar'), findsNothing);
    expect(find.text('Denunciar'), findsOneWidget);
  });

  testWidgets('post removido nao oferece acoes', (tester) async {
    await tester.pumpWidget(_wrap(PostCard(
      post: _post(removed: true, removedBy: 'author'),
      onTap: () {},
      currentAnonymousId: 'eu',
      onDelete: () {},
      onReport: () {},
    )));

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
