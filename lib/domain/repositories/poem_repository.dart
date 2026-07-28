import '../poem.dart';
import '../learning_models.dart';

abstract class PoemRepository {
  Future<void> importSeedIfNeeded({required String seedVersion});
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()});
  Future<Poem?> fetchPoemById(int id);
  Future<List<Poem>> fetchFavorites();
  Future<void> setFavorite(int poemId, bool isFavorite);
  Future<bool> isFavorite(int poemId);
  Future<PoemStats> fetchStats();
  Future<DailyPoemBundle> getDailyPoem(DateTime date);
}

