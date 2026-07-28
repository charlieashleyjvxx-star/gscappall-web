import '../poem.dart';
import '../practice_models.dart';

abstract class PracticeRepository {
  Future<List<Poem>> fetchPracticePoems({int limit = 60});

  Future<PracticeSession> createSession({
    required PracticeMode mode,
    int? poemId,
    DictationDifficulty difficulty = DictationDifficulty.standard,
    DictationAnswerMode answerMode = DictationAnswerMode.fullText,
  });

  PracticeLineResult evaluateAnswer({
    required PracticeQuestion question,
    required String answer,
  });

  Future<PracticeReport> completeSession({
    required PracticeSession session,
    required Map<int, String> answers,
  });
  Future<PracticeReport> saveAssessmentReport({
    required Poem poem,
    required PracticeMode mode,
    required List<PracticeLineResult> results,
    DateTime? completedAt,
  });

  Future<List<PracticeReportSummary>> fetchPracticeReportSummaries({
    int limit = 100,
  });

  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  });

  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id);

  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  });

  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id);

  Future<void> markWrongQuestionReviewed(int id);
}
