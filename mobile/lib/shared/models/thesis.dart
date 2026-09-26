import 'thesis_explanation.dart';

enum ThesisAnswer { agree, neutral, disagree, skipped, unanswered }

class Thesis {
  final int id;
  final String title;
  final String category;
  final ThesisExplanation? explanation;
  ThesisAnswer answer;
  bool doubleWeight;

  Thesis({
    required this.id,
    required this.title,
    required this.category,
    this.explanation,
    this.answer = ThesisAnswer.unanswered,
    this.doubleWeight = false,
  });

  factory Thesis.fromJson(Map<String, dynamic> json) {
    return Thesis(
      id: json['id'] as int,
      title: json['text'] as String,
      category: json['theme_name'] as String,
      explanation: json['explanation'] == null
          ? null
          : ThesisExplanation.fromJson(
              json['explanation'] as Map<String, dynamic>,
            ),
    );
  }

  String get apiAnswer {
    switch (answer) {
      case ThesisAnswer.agree:
        return 'agree';
      case ThesisAnswer.neutral:
        return 'neutral';
      case ThesisAnswer.disagree:
        return 'disagree';
      case ThesisAnswer.skipped:
        return 'skip';
      case ThesisAnswer.unanswered:
        return 'skip';
    }
  }

  bool get wasAnswered => answer != ThesisAnswer.unanswered;

  Map<String, dynamic> toSubmitJson() {
    return {
      'thesis_id': id,
      'answer': apiAnswer,
      'weight': doubleWeight ? 2 : 1,
    };
  }
}
