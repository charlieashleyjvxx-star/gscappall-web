import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/local/local_seed_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seed keeps tonal pinyin for Yong E', () async {
    final poems = await const LocalSeedLoader().loadPoems();
    final poem = poems.singleWhere((entry) => entry.title == '咏鹅');

    expect(poem.pinyinLines.first, 'é é é');
    expect(poem.pinyinLines[1], 'qū xiàng xiàng tiān gē');
  });
}
