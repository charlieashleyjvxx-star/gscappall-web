import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../domain/practice_models.dart';
import '../../shared/widgets/section_card.dart';

class WrongQuestionRetryPage extends ConsumerStatefulWidget {
  const WrongQuestionRetryPage({super.key, required this.entry});

  final WrongQuestionEntry entry;

  @override
  ConsumerState<WrongQuestionRetryPage> createState() =>
      _WrongQuestionRetryPageState();
}

class _WrongQuestionRetryPageState
    extends ConsumerState<WrongQuestionRetryPage> {
  final TextEditingController _answerController = TextEditingController();

  PracticeLineResult? _result;
  bool _isSubmitting = false;
  bool _completed = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Scaffold(
      appBar: AppBar(title: const Text('错题再练')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              title: entry.poemTitle,
              subtitle: '${entry.poemAuthor} · ${entry.questionType.label}',
              trailing: Chip(label: Text(entry.mistakeType.label)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailBlock(label: '原题', value: entry.prompt),
                  _DetailBlock(
                    label: '上次答案',
                    value: entry.userAnswer.isEmpty ? '未作答' : entry.userAnswer,
                  ),
                  _DetailBlock(label: '目标答案', value: entry.correctAnswer),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: '重新作答',
              subtitle: '重新输入这句诗，系统会按同一规则再次校验。',
              child: Column(
                children: [
                  TextField(
                    controller: _answerController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '在这里重新输入这句诗',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitRetry,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(_completed ? '再次校验' : '开始校验'),
                  ),
                ],
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 18),
              _ResultCard(result: _result!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitRetry() async {
    final answer = _answerController.text.trim();
    final question = PracticeQuestion(
      poemId: widget.entry.poemId,
      poemTitle: widget.entry.poemTitle,
      poemAuthor: widget.entry.poemAuthor,
      lineIndex: 0,
      prompt: widget.entry.prompt,
      hint: '从错题本回到原题再练一次。',
      expectedAnswer: widget.entry.correctAnswer,
    );

    setState(() {
      _isSubmitting = true;
    });

    final result = ref
        .read(practiceRepositoryProvider)
        .evaluateAnswer(question: question, answer: answer);

    if (result.isCorrect) {
      await ref
          .read(practiceRepositoryProvider)
          .markWrongQuestionReviewed(widget.entry.id);
      await ref
          .read(learningRepositoryProvider)
          .logLearningRecord(
            poemId: widget.entry.poemId,
            mode: 'wrong_question_retry',
            durationMinutes: 2,
            score: result.score,
            note: '从错题本完成一次再练',
          );
      ref.invalidate(learningSummaryProvider);
      ref.invalidate(recentLearningRecordsProvider);
      ref.invalidate(
        wrongQuestionEntriesProvider(const WrongQuestionQuery(limit: 300)),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _isSubmitting = false;
      _completed = result.isCorrect;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isCorrect ? '这道错题已重新掌握，并已标记为已复习。' : '还差一点，再根据反馈修正一次。',
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PracticeLineResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: result.isCorrect ? '本次通过' : '继续修正',
      subtitle: result.isCorrect ? '这句已经重新掌握，可以回到错题本继续复盘。' : '系统已按原规则给出反馈。',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              result.isCorrect
                  ? const Color(0xFFE7F4E4)
                  : const Color(0xFFFBE8E0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.isCorrect
                  ? '正确 ${result.score}'
                  : '${result.mistakeType?.label ?? '待复习'} ${result.score}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('你的答案：${result.answer.isEmpty ? '未作答' : result.answer}'),
            const SizedBox(height: 6),
            Text('标准答案：${result.question.expectedAnswer}'),
            const SizedBox(height: 6),
            Text(result.feedback),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}
