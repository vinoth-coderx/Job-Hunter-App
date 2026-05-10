import 'api_client.dart';

class MockInterviewSession {
  final String id;
  final String role;
  final String interviewType;
  final int questionsAsked;
  final int questionsTarget;
  final String latestQuestion;
  const MockInterviewSession({
    required this.id,
    required this.role,
    required this.interviewType,
    required this.questionsAsked,
    required this.questionsTarget,
    required this.latestQuestion,
  });
  factory MockInterviewSession.fromJson(Map<String, dynamic> j) =>
      MockInterviewSession(
        id: (j['id'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        interviewType: (j['interviewType'] ?? 'behavioural').toString(),
        questionsAsked: (j['questionsAsked'] as num?)?.toInt() ?? 0,
        questionsTarget: (j['questionsTarget'] as num?)?.toInt() ?? 6,
        latestQuestion: (j['latestQuestion'] ?? '').toString(),
      );
}

class MockTurnFeedback {
  final int? relevance;
  final int? depth;
  final int? communication;
  final String? suggestion;
  const MockTurnFeedback({
    this.relevance,
    this.depth,
    this.communication,
    this.suggestion,
  });
  factory MockTurnFeedback.fromJson(Map<String, dynamic> j) =>
      MockTurnFeedback(
        relevance: (j['relevance'] as num?)?.toInt(),
        depth: (j['depth'] as num?)?.toInt(),
        communication: (j['communication'] as num?)?.toInt(),
        suggestion: j['suggestion'] as String?,
      );
}

class MockAnswerResult {
  final String id;
  final int questionsAsked;
  final int questionsTarget;
  final MockTurnFeedback? latestFeedback;
  final String latestQuestion;
  final bool shouldFinish;

  /// Backend says the candidate's answer was completely off-topic. The
  /// UI should warn the user, keep the same question on screen, and not
  /// advance the progress bar.
  final bool answerWasIrrelevant;

  const MockAnswerResult({
    required this.id,
    required this.questionsAsked,
    required this.questionsTarget,
    this.latestFeedback,
    required this.latestQuestion,
    required this.shouldFinish,
    this.answerWasIrrelevant = false,
  });
  factory MockAnswerResult.fromJson(Map<String, dynamic> j) => MockAnswerResult(
        id: (j['id'] ?? '').toString(),
        questionsAsked: (j['questionsAsked'] as num?)?.toInt() ?? 0,
        questionsTarget: (j['questionsTarget'] as num?)?.toInt() ?? 6,
        latestFeedback: j['latestFeedback'] is Map<String, dynamic>
            ? MockTurnFeedback.fromJson(
                j['latestFeedback'] as Map<String, dynamic>)
            : null,
        latestQuestion: (j['latestQuestion'] ?? '').toString(),
        shouldFinish: j['shouldFinish'] as bool? ?? false,
        answerWasIrrelevant: j['answerWasIrrelevant'] as bool? ?? false,
      );
}

class MockInterviewSummary {
  final int finalScore;
  final String finalSummary;
  const MockInterviewSummary({
    required this.finalScore,
    required this.finalSummary,
  });
  factory MockInterviewSummary.fromJson(Map<String, dynamic> j) =>
      MockInterviewSummary(
        finalScore: (j['finalScore'] as num?)?.toInt() ?? 0,
        finalSummary: (j['finalSummary'] ?? '').toString(),
      );
}

class MockInterviewService {
  MockInterviewService._();
  static final MockInterviewService instance = MockInterviewService._();
  final ApiClient _api = ApiClient.instance;

  Future<MockInterviewSession> start({
    required String role,
    String interviewType = 'behavioural',
    int? questionsTarget,
  }) async {
    final raw = await _api.post('mock-interviews/start', body: {
      'role': role,
      'interviewType': interviewType,
      if (questionsTarget != null) 'questionsTarget': questionsTarget,
    });
    return MockInterviewSession.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<MockAnswerResult> answer({
    required String id,
    required String answer,
  }) async {
    final raw = await _api.post('mock-interviews/$id/answer', body: {
      'answer': answer,
    });
    return MockAnswerResult.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<MockInterviewSummary> finish(String id) async {
    final raw = await _api.post('mock-interviews/$id/finish');
    return MockInterviewSummary.fromJson(ApiClient.unwrapMap(raw));
  }
}
