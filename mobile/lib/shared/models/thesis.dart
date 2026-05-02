enum ThesisAnswer { agree, neutral, disagree, skipped, unanswered }

class Thesis {
  final int id;
  final String title;
  final String category;
  ThesisAnswer answer;
  bool doubleWeight;

  Thesis({
    required this.id,
    required this.title,
    required this.category,
    this.answer = ThesisAnswer.unanswered,
    this.doubleWeight = false,
  });

  factory Thesis.fromJson(Map<String, dynamic> json) {
    return Thesis(
      id: json['id'] as int,
      title: json['text'] as String,
      category: json['theme_name'] as String? ?? json['theme_id'] as String,
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
