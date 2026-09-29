
/// Question Model representing documents in the /questions collection
class Question {
  final String id;
  final int grade;
  final String contentDomain;
  final String competencyCode;
  final String competencyText;
  final String cognitiveDomain;
  final String type; // 'multipleChoice' | 'numericInput' | 'computation' | 'trueFalse'
  final String questionText;
  final List<String>? choices;
  final dynamic correctAnswer; // String or List<String>
  final int maxPoints;
  final String? scoringRubric;
  final String? groupId;
  final String? sharedStimulusId;

  const Question({
    required this.id,
    required this.grade,
    required this.contentDomain,
    required this.competencyCode,
    required this.competencyText,
    required this.cognitiveDomain,
    required this.type,
    required this.questionText,
    this.choices,
    required this.correctAnswer,
    this.maxPoints = 1,
    this.scoringRubric,
    this.groupId,
    this.sharedStimulusId,
  });

  factory Question.fromMap(Map<String, dynamic> map, String docId) {
    final rawChoices = map['choices'];
    List<String>? choicesList;
    if (rawChoices is List) {
      choicesList = rawChoices.map((e) => e.toString()).toList();
    }

    return Question(
      id: docId,
      grade: (map['grade'] ?? 1) as int,
      contentDomain: map['contentDomain']?.toString() ?? '',
      competencyCode: map['competencyCode']?.toString() ?? '',
      competencyText: map['competencyText']?.toString() ?? '',
      cognitiveDomain: map['cognitiveDomain']?.toString() ?? 'Knowing',
      type: map['type']?.toString() ?? 'multipleChoice',
      questionText: map['questionText']?.toString() ?? '',
      choices: choicesList,
      correctAnswer: map['correctAnswer'],
      maxPoints: (map['maxPoints'] ?? 1) as int,
      scoringRubric: map['scoringRubric']?.toString(),
      groupId: map['groupId']?.toString(),
      sharedStimulusId: map['sharedStimulusId']?.toString(),
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grade': grade,
      'contentDomain': contentDomain,
      'competencyCode': competencyCode,
      'competencyText': competencyText,
      'cognitiveDomain': cognitiveDomain,
      'type': type,
      'questionText': questionText,
      'choices': choices,
      'correctAnswer': correctAnswer,
      'maxPoints': maxPoints,
      'scoringRubric': scoringRubric,
      'groupId': groupId,
      'sharedStimulusId': sharedStimulusId,
    };
  }
}
