import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/quiz/quiz_controller.dart';
import 'package:guia_eleitoral/features/quiz/quiz_page.dart';
import 'package:guia_eleitoral/features/quiz/thesis_explanation_panel.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/models/thesis_explanation.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

class _SilentAnalytics implements AnalyticsSink {
  @override
  Future<void> logEvent(
      {required String name, Map<String, Object>? parameters}) async {}
}

const _paragraph =
    'Arcabouço fiscal é um conjunto de regras para as contas do governo.';
final _explanation = ThesisExplanation(
  paragraphs: [
    _paragraph,
    ...List.filled(5,
        'Uma explicação mais longa que pode ser lida enquanto as opções de resposta continuam acessíveis na tela.')
  ],
  sources: [
    ExplanationSource(
        title: 'Lei Complementar nº 200/2023',
        url: Uri.parse(
            'https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp200.htm'))
  ],
);

void main() {
  setUpAll(() async {
    for (final font in {
      'Inter_regular': 'Regular',
      'Inter_600': 'SemiBold',
      'Inter_800': 'ExtraBold',
    }.entries) {
      final bytes = await File('test/fixtures/fonts/Inter-${font.value}.ttf')
          .readAsBytes();
      await (FontLoader(font.key)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<QuizSession> pumpQuiz(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool withExplanation = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = QuizSession.testOnly()
      ..theses = [
        Thesis(
            id: 31,
            title:
                'O governo federal deve manter o arcabouço fiscal previsto na Lei Complementar nº 200/2023.',
            category: 'Economia',
            explanation: withExplanation ? _explanation : null),
        Thesis(
            id: 32,
            title:
                'Todas as empresas estatais devem ser transferidas ao controle privado.',
            category: 'Economia',
            explanation: const ThesisExplanation(paragraphs: [
              'Explicação da segunda pergunta.',
              'Segundo parágrafo.'
            ], sources: [])),
      ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: QuizPage(
        iotEnabled: false,
        controller: QuizController(
            session: session,
            analytics: AnalyticsService(sink: _SilentAnalytics())),
      ),
      routes: {
        '/weighting': (_) => const Scaffold(body: Text('Revisar respostas'))
      },
    ));
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('help opens inline without answering and all answers stay pinned',
      (tester) async {
    final session = await pumpQuiz(tester);
    expect(find.text(_paragraph), findsNothing);
    final answerPosition = tester.getRect(find.text('CONCORDO'));
    await tester.tap(find.text('Entenda esta pergunta'));
    await tester.pumpAndSettle();
    expect(find.text(_paragraph), findsOneWidget);
    expect(session.theses.first.answer, ThesisAnswer.unanswered);
    for (final label in [
      'CONCORDO',
      'NEUTRO',
      'DISCORDO',
      'PULAR ESTA QUESTÃO'
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('CONCORDO')), answerPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each new question starts at the top with its own help collapsed',
      (tester) async {
    final session = await pumpQuiz(tester);
    await tester.tap(find.text('Entenda esta pergunta'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONCORDO'));
    await tester.pumpAndSettle();
    expect(session.theses.first.answer, ThesisAnswer.agree);
    expect(find.text(_paragraph), findsNothing);
    expect(find.text('Explicação da segunda pergunta.'), findsNothing);
    expect(find.text(session.theses[1].title).hitTestable(), findsOneWidget);
    await tester.tap(find.text('Entenda esta pergunta'));
    await tester.pumpAndSettle();
    expect(find.text('Explicação da segunda pergunta.'), findsOneWidget);
    await tester.tap(find.text('VOLTAR'));
    await tester.pumpAndSettle();
    expect(find.text(_paragraph), findsNothing);
    expect(find.text(session.theses.first.title).hitTestable(), findsOneWidget);
  });

  for (final choice in {
    'NEUTRO': ThesisAnswer.neutral,
    'DISCORDO': ThesisAnswer.disagree,
    'PULAR ESTA QUESTÃO': ThesisAnswer.skipped
  }.entries) {
    testWidgets('${choice.key} works while the explanation is open',
        (tester) async {
      final session = await pumpQuiz(tester);
      await tester.tap(find.text('Entenda esta pergunta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(choice.key));
      await tester.pumpAndSettle();
      expect(session.theses.first.answer, choice.value);
      expect(find.text('2/2'), findsOneWidget);
    });
  }

  testWidgets('older API without explanation remains answerable',
      (tester) async {
    final session = await pumpQuiz(tester, withExplanation: false);
    expect(find.text('Entenda esta pergunta'), findsNothing);
    await tester.tap(find.text('CONCORDO'));
    await tester.pumpAndSettle();
    expect(session.theses.first.answer, ThesisAnswer.agree);
  });

  testWidgets('small phone exposes help and every answer without scrolling',
      (tester) async {
    await pumpQuiz(tester, size: const Size(320, 568));
    for (final label in [
      'Entenda esta pergunta',
      'CONCORDO',
      'NEUTRO',
      'DISCORDO',
      'PULAR ESTA QUESTÃO',
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('readable without overflow at $size with text scale $scale',
          (tester) async {
        await pumpQuiz(tester, size: size, scale: scale);
        await tester.ensureVisible(find.text('Entenda esta pergunta'));
        await tester.tap(find.text('Entenda esta pergunta'));
        await tester.pumpAndSettle();
        expect(find.text(_paragraph), findsOneWidget);
        await tester.ensureVisible(find.text('PULAR ESTA QUESTÃO'));
        expect(find.text('PULAR ESTA QUESTÃO').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('help has accessible touch targets and expands from the keyboard',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ThesisExplanationPanel(explanation: _explanation)))));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_paragraph), findsOneWidget);
      expect(
          tester.getSemantics(find.byType(MergeSemantics).first),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            isFocused: true,
            hasFocusAction: true,
            hasTapAction: true,
            hasExpandedState: true,
            isExpanded: true,
            label: 'Entenda esta pergunta\nToque para recolher',
          ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(_paragraph), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('source links use the cited URL and report an opening failure',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
              child: ThesisExplanationPanel(
            explanation: _explanation,
            linkOpener: (url) async {
              opened = url;
              return false;
            },
          )),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entenda esta pergunta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lei Complementar nº 200/2023'));
    await tester.tap(find.text('Lei Complementar nº 200/2023'));
    await tester.pumpAndSettle();
    expect(opened, _explanation.sources.first.url);
    expect(find.text('Não foi possível abrir a fonte. Tente novamente.'),
        findsOneWidget);
  });

  test('parses help while keeping the submitted answer payload unchanged', () {
    final thesis = Thesis.fromJson({
      'id': 31,
      'text': 'Pergunta',
      'theme_name': 'Economia',
      'explanation': {
        'paragraphs': ['Explicação.', 'Contexto.'],
        'sources': [
          {'title': 'Fonte', 'url': 'https://example.org/lei'}
        ]
      },
    })
      ..answer = ThesisAnswer.neutral;
    expect(thesis.explanation!.paragraphs, ['Explicação.', 'Contexto.']);
    expect(thesis.toSubmitJson(),
        {'thesis_id': 31, 'answer': 'neutral', 'weight': 1});
    expect(
        Thesis.fromJson({'id': 1, 'text': 'Pergunta', 'theme_name': 'Tema'})
            .explanation,
        isNull);
    expect(
        () => ExplanationSource.fromJson(
            {'title': 'Fonte', 'url': 'javascript:alert(1)'}),
        throwsFormatException);
  });
}
