class Poem {
  const Poem({
    required this.id,
    required this.title,
    required this.author,
    required this.dynasty,
    required this.grade,
    required this.gradeLabel,
    required this.category,
    required this.content,
    required this.pinyin,
    required this.annotation,
    required this.translation,
    required this.appreciation,
    required this.authorIntro,
    required this.extension,
    required this.audioUrl,
    required this.imageUrl,
    required this.difficulty,
  });

  final int id;
  final String title;
  final String author;
  final String dynasty;
  final int grade;
  final String gradeLabel;
  final String category;
  final String content;
  final String pinyin;
  final String annotation;
  final String translation;
  final String appreciation;
  final String authorIntro;
  final String extension;
  final String? audioUrl;
  final String? imageUrl;
  final int difficulty;

  List<String> get lines => content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  List<String> get pinyinLines => pinyin
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  // ignore: sort_constructors_first
  factory Poem.fromJson(Map<String, dynamic> json) {
    return Poem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      dynasty: json['dynasty'] as String? ?? '',
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      gradeLabel: json['gradeLabel'] as String? ?? '',
      category: json['category'] as String? ?? '',
      content: json['content'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      annotation: json['annotation'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      appreciation: json['appreciation'] as String? ?? '',
      authorIntro: json['authorIntro'] as String? ?? '',
      extension: json['extension'] as String? ?? '',
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    );
  }

  // ignore: sort_constructors_first
  factory Poem.fromRow(Map<String, Object?> row) {
    return Poem(
      id: (row['id'] as int?) ?? 0,
      title: row['title'] as String? ?? '',
      author: row['author'] as String? ?? '',
      dynasty: row['dynasty'] as String? ?? '',
      grade: (row['grade'] as int?) ?? 0,
      gradeLabel: row['grade_label'] as String? ?? '',
      category: row['category'] as String? ?? '',
      content: row['content'] as String? ?? '',
      pinyin: row['pinyin'] as String? ?? '',
      annotation: row['annotation'] as String? ?? '',
      translation: row['translation'] as String? ?? '',
      appreciation: row['appreciation'] as String? ?? '',
      authorIntro: row['author_intro'] as String? ?? '',
      extension: row['extension_text'] as String? ?? '',
      audioUrl: row['audio_url'] as String?,
      imageUrl: row['image_url'] as String?,
      difficulty: (row['difficulty'] as int?) ?? 1,
    );
  }
}

class PoemQuery {
  const PoemQuery({this.search = '', this.grade, this.category, this.dynasty});

  final String search;
  final int? grade;
  final String? category;
  final String? dynasty;

  PoemQuery copyWith({
    String? search,
    int? grade,
    String? category,
    String? dynasty,
    bool clearGrade = false,
    bool clearCategory = false,
    bool clearDynasty = false,
  }) {
    return PoemQuery(
      search: search ?? this.search,
      grade: clearGrade ? null : (grade ?? this.grade),
      category: clearCategory ? null : (category ?? this.category),
      dynasty: clearDynasty ? null : (dynasty ?? this.dynasty),
    );
  }
}

class PoemStats {
  const PoemStats({
    required this.total,
    required this.gradeCounts,
    required this.categoryCounts,
    required this.dynastyCounts,
  });

  final int total;
  final Map<String, int> gradeCounts;
  final Map<String, int> categoryCounts;
  final Map<String, int> dynastyCounts;
}
