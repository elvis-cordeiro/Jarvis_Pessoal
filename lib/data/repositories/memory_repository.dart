import 'package:drift/drift.dart';
import '../database/app_database.dart';

class MemoryRepository {
  final AppDatabase db;

  MemoryRepository(this.db);

  // ====================== NÍVEL 1 — PERMANENTE ======================
  // Personalidade, preferências, rotinas — nunca expira
  Future<void> savePermanentMemory({
    required String content,
    required String category,
  }) async {
    await db.into(db.longTermMemory).insert(
      LongTermMemoryCompanion(
        category: Value(category),
        content: Value(content),
        source: const Value('conversation'),
        // expiresAt ausente = null = permanente
      ),
    );
  }

  // ====================== NÍVEL 2 — LONGO PRAZO (10 anos) ======================
  // Assuntos importantes, fatos relevantes
  Future<void> saveLongTermMemory({
    required String content,
    String category = 'general',
  }) async {
    await db.into(db.longTermMemory).insert(
      LongTermMemoryCompanion(
        category: Value(category),
        content: Value(content),
        source: const Value('conversation'),
        expiresAt: Value(DateTime.now().add(const Duration(days: 3650))),
      ),
    );
  }

  // ====================== NÍVEL 3 — TEMPORÁRIA (3 meses) ======================
  // Rotina do dia, assuntos passageiros
  Future<void> saveTemporaryMemory({
    required String content,
  }) async {
    await db.into(db.temporaryMemory).insert(
      TemporaryMemoryCompanion(
        content: Value(content),
        expiresAt: Value(DateTime.now().add(const Duration(days: 90))),
      ),
    );
  }

  // ====================== BUSCAR ======================

  // Busca todas as memórias de longo prazo válidas (permanentes + não expiradas)
  Future<List<LongTermMemoryData>> getAllLongTermMemories() async {
    final now = DateTime.now();
    final all = await db.select(db.longTermMemory).get();
    return all
        .where((m) => m.expiresAt == null || m.expiresAt!.isAfter(now))
        .toList();
  }

  // Busca apenas memórias permanentes (expiresAt == null)
  Future<List<LongTermMemoryData>> getPermanentMemories() async {
    final all = await db.select(db.longTermMemory).get();
    return all.where((m) => m.expiresAt == null).toList();
  }

  // Busca memórias de longo prazo com expiração (não expiradas)
  Future<List<LongTermMemoryData>> getActiveLongTermMemories() async {
    final now = DateTime.now();
    final all = await db.select(db.longTermMemory).get();
    return all
        .where((m) => m.expiresAt != null && m.expiresAt!.isAfter(now))
        .toList();
  }

  // Busca memórias temporárias válidas
  Future<List<TemporaryMemoryData>> getActiveTemporaryMemories() async {
    final now = DateTime.now();
    final all = await db.select(db.temporaryMemory).get();
    return all.where((m) => m.expiresAt.isAfter(now)).toList();
  }

  // ====================== LIMPEZA ======================
  Future<void> cleanExpiredMemories() async {
    final now = DateTime.now();

    // Remove temporárias expiradas
    final allTemp = await db.select(db.temporaryMemory).get();
    for (final m in allTemp) {
      if (m.expiresAt.isBefore(now)) {
        await (db.delete(db.temporaryMemory)
              ..where((tbl) => tbl.id.equals(m.id)))
            .go();
      }
    }

    // Remove long term expiradas (permanentes nunca são removidas)
    final allLong = await db.select(db.longTermMemory).get();
    for (final m in allLong) {
      if (m.expiresAt != null && m.expiresAt!.isBefore(now)) {
        await (db.delete(db.longTermMemory)
              ..where((tbl) => tbl.id.equals(m.id)))
            .go();
      }
    }
  }
}