import 'package:drift/drift.dart';
import '../database/app_database.dart';

class MemoryRepository {
  final AppDatabase db;

  MemoryRepository(this.db);

  // ====================== SALVAR MEMÓRIAS ======================

  Future<void> saveLongTermMemory({
    required String content,
    String category = 'general',
    DateTime? expiresAt,
  }) async {
    await db.into(db.longTermMemory).insert(
      LongTermMemoryCompanion(
        category: Value(category),
        content: Value(content),
        source: const Value('voice'),
        expiresAt: expiresAt != null ? Value(expiresAt) : const Value.absent(),
      ),
    );
    print('💾 Memorizado em Long Term: $content');
  }

  Future<void> saveTemporaryMemory({
    required String content,
    DateTime? expiresAt,
  }) async {
    final finalExpires = expiresAt ?? DateTime.now().add(const Duration(days: 90));

    await db.into(db.temporaryMemory).insert(
      TemporaryMemoryCompanion(
        content: Value(content),
        expiresAt: Value(finalExpires),
      ),
    );
    print('📂 Memorizado em Temporary: $content');
  }

  // ====================== LIMPEZA ======================

  Future<void> cleanExpiredMemories() async {
    final now = DateTime.now();

    await (db.delete(db.temporaryMemory)
          ..where((tbl) => tbl.expiresAt.isSmallerThanValue(now)))
        .go();

    await (db.delete(db.longTermMemory)
          ..where((tbl) => 
              tbl.expiresAt.isNotNull() & tbl.expiresAt.isSmallerThanValue(now)))
        .go();

    print('🧹 Limpeza realizada.');
  }

  // ====================== BUSCAR ======================

  Future<List<LongTermMemoryData>> getPersonalityMemories() async {
    return await (db.select(db.longTermMemory)
          ..where((tbl) => 
              tbl.category.equals('personalidade') | 
              tbl.category.equals('preferencias')))
        .get();
  }
}