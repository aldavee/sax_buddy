import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sax_buddy/features/sax/data/sax_catalog_data.dart';
import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaxRepository extends ChangeNotifier {
  SaxRepository._();

  static final SaxRepository instance = SaxRepository._();

  static const String _prefItemsKey = 'sax_buddy_items_v1';
  static const String _prefFoldersKey = 'sax_buddy_folders_v1';
  static const String _prefScalesKey = 'sax_buddy_scales_v1';
  static const String _prefHornKey = 'sax_buddy_selected_horn_v1';
  static const String _prefWeeklyGoalKey = 'sax_buddy_weekly_goal_minutes_v1';

  static const List<String> defaultFolders = <String>[
    'Daily Routine',
    'Repertoire',
    'Technique',
    'Transcribing',
    'Gear & Reeds',
  ];

  final List<SaxPracticeItem> _items = <SaxPracticeItem>[];
  final List<String> _folders = List<String>.from(defaultFolders);
  final Map<String, SaxScaleProgress> _scaleProgress =
      <String, SaxScaleProgress>{};

  SaxHornType _selectedHorn = SaxHornType.alto;
  int _weeklyGoalMinutes = 180;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  SaxHornType get selectedHorn => _selectedHorn;
  int get weeklyGoalMinutes => _weeklyGoalMinutes;
  List<String> get folders => List<String>.unmodifiable(_folders);
  List<SaxPracticeItem> get allItems => List<SaxPracticeItem>.unmodifiable(_items);

  List<SaxPracticeItem> get activeItems => _sorted(
        _items.where((n) => !n.isArchived && !n.isTrashed),
      );

  List<SaxPracticeItem> get favoriteItems => _sorted(
        _items.where((n) => n.isFavorite && !n.isTrashed),
      );

  List<SaxPracticeItem> get checklistItems => _sorted(
        _items.where((n) => n.isChecklist && !n.isTrashed && !n.isArchived),
      );

  List<SaxPracticeItem> get archivedItems => _sorted(
        _items.where((n) => n.isArchived && !n.isTrashed),
      );

  List<SaxPracticeItem> get trashedItems => _sorted(
        _items.where((n) => n.isTrashed),
      );

  List<String> get allTags {
    final set = <String>{};
    for (final item in _items) {
      if (!item.isTrashed) {
        set.addAll(item.tags);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  int get totalPracticeMinutes => _items
      .where((i) => !i.isTrashed)
      .fold<int>(0, (sum, item) => sum + item.durationMinutes);

  int get masteredScalesCount =>
      _scaleProgress.values.where((p) => p.masteryLevel >= 3).length;

  int get averageTargetBpm {
    final active = activeItems;
    if (active.isEmpty) return 120;
    final total = active.fold<int>(0, (sum, i) => sum + i.targetBpm);
    return (total / active.length).round();
  }

  List<SaxPracticeItem> _sorted(Iterable<SaxPracticeItem> source) {
    final list = source.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();

    final savedHorn = prefs.getString(_prefHornKey);
    if (savedHorn != null) {
      _selectedHorn = SaxHornType.values.firstWhere(
        (h) => h.name == savedHorn,
        orElse: () => SaxHornType.alto,
      );
    }
    _weeklyGoalMinutes = prefs.getInt(_prefWeeklyGoalKey) ?? 180;

    final rawFolders = prefs.getStringList(_prefFoldersKey);
    if (rawFolders != null && rawFolders.isNotEmpty) {
      _folders
        ..clear()
        ..addAll(rawFolders);
    }

    final rawScales = prefs.getString(_prefScalesKey);
    if (rawScales != null && rawScales.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawScales);
        if (decoded is List) {
          _scaleProgress.clear();
          for (final entry in decoded.whereType<Map<String, dynamic>>()) {
            final p = SaxScaleProgress.fromJson(entry);
            _scaleProgress[p.compositeKey] = p;
          }
        }
      } catch (_) {}
    }

    final rawItems = prefs.getString(_prefItemsKey);
    if (rawItems != null && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map<String, dynamic>>()
                  .map(SaxPracticeItem.fromJson),
            );
        }
      } catch (_) {}
    }

    if (_items.isEmpty) {
      _seedStarterItems();
      await _persist();
    }
    notifyListeners();
  }

  void _seedStarterItems() {
    final now = DateTime.now().toUtc();
    _items.addAll([
      SaxPracticeItem(
        id: 'seed-sax-1',
        title: 'Welcome to Sax Buddy Studio',
        content:
            'Your offline-first saxophone practice studio, interactive 23-key fingering & altissimo chart, precision metronome & drone, 12-key scales trainer, and Eb/Bb/Concert horn transposer.\n\n'
            '• Switch between Alto (Eb), Tenor (Bb), Soprano (Bb), and Baritone (Eb).\n'
            '• Back up & merge your practice logs, repertoire charts, and scale tempos via Google Drive (F5).',
        folder: 'Daily Routine',
        horn: SaxHornType.alto,
        keySignature: 'Eb',
        targetBpm: 120,
        durationMinutes: 25,
        tags: const ['warmup', 'overtones', 'daily'],
        isPinned: true,
        isFavorite: true,
        color: PracticeCardColor.brass,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      ),
      SaxPracticeItem(
        id: 'seed-sax-2',
        title: 'Daily Saxophone Warmup Checklist',
        content: 'Core tone, overtone voicing, and articulation routine.',
        folder: 'Daily Routine',
        horn: SaxHornType.alto,
        keySignature: 'Bb',
        targetBpm: 108,
        durationMinutes: 30,
        tags: const ['long-tones', 'voicing', 'scales'],
        isChecklist: true,
        isPinned: true,
        color: PracticeCardColor.emerald,
        checklist: const [
          PracticeChecklistItem(
            id: 'chk-1',
            text: 'Long Tones: Low Bb3 -> Chromatic up to F#6 with drone (8 min)',
            isDone: true,
          ),
          PracticeChecklistItem(
            id: 'chk-2',
            text: 'Overtones on Low Bb, B, C, Db: match fundamental & 1st/2nd harmonics (7 min)',
            isDone: false,
          ),
          PracticeChecklistItem(
            id: 'chk-3',
            text: 'Full-Range Major & Dorian Scales through Circle of 4ths @ 108 BPM (10 min)',
            isDone: false,
          ),
          PracticeChecklistItem(
            id: 'chk-4',
            text: 'ii-V-I Bebop Enclosures & 1-2-3-5 Digital Patterns (5 min)',
            isDone: false,
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
      ),
      SaxPracticeItem(
        id: 'seed-sax-3',
        title: 'Blue Bossa — Eb Alto Lead Changes & Solo Plan',
        content:
            'Alto Sax Written Changes (A Minor / Bb Major):\n'
            '| Am7   | Am7   | Dm7   | G7    |\n'
            '| Bm7b5 | E7alt | Am7   | Am7   |\n'
            '| Cm7   | F7    | BbMaj7| BbMaj7|\n'
            '| Bm7b5 | E7alt | Am7   | Bm7b5 E7alt |\n\n'
            'Focus: Smooth voice-leading from Am7 (A Dorian) into Cm7–F7–BbMaj7 modulate section using Bis Bb.',
        folder: 'Repertoire',
        horn: SaxHornType.alto,
        keySignature: 'Am',
        targetBpm: 144,
        durationMinutes: 20,
        tags: const ['bossa', 'ii-V-I', 'repertoire'],
        isFavorite: true,
        color: PracticeCardColor.cobalt,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      SaxPracticeItem(
        id: 'seed-sax-4',
        title: 'Mouthpiece & Reed Rotation Locker',
        content:
            'Alto Setup: Meyer 5M Hard Rubber + Vandoren Java Green 2.5 (#1 Concert Ready, #2 Practice Rotation).\n'
            'Tenor Setup: Otto Link Tone Edge 7* + Rigotti Gold Jazz 3 Medium.',
        folder: 'Gear & Reeds',
        horn: SaxHornType.tenor,
        keySignature: 'Bb',
        targetBpm: 120,
        durationMinutes: 10,
        tags: const ['reeds', 'mouthpiece', 'setup'],
        color: PracticeCardColor.violet,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);

    _scaleProgress['major::C'] = SaxScaleProgress(
      scaleId: 'major',
      rootKey: 'C',
      achievedBpm: 132,
      targetBpm: 140,
      masteryLevel: 3,
      updatedAt: now,
    );
    _scaleProgress['dorian::D'] = SaxScaleProgress(
      scaleId: 'dorian',
      rootKey: 'D',
      achievedBpm: 116,
      targetBpm: 132,
      masteryLevel: 2,
      updatedAt: now,
    );
    _scaleProgress['blues::Bb'] = SaxScaleProgress(
      scaleId: 'blues',
      rootKey: 'Bb',
      achievedBpm: 128,
      targetBpm: 132,
      masteryLevel: 3,
      updatedAt: now,
    );
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefItemsKey,
        jsonEncode(_items.map((n) => n.toJson()).toList()),
      );
      await prefs.setStringList(_prefFoldersKey, _folders);
      await prefs.setString(
        _prefScalesKey,
        jsonEncode(_scaleProgress.values.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(_prefHornKey, _selectedHorn.name);
      await prefs.setInt(_prefWeeklyGoalKey, _weeklyGoalMinutes);
    } catch (_) {}
  }

  Future<void> setSelectedHorn(SaxHornType horn) async {
    if (_selectedHorn == horn) return;
    _selectedHorn = horn;
    await _persist();
    notifyListeners();
  }

  Future<void> setWeeklyGoalMinutes(int minutes) async {
    _weeklyGoalMinutes = minutes.clamp(30, 1200);
    await _persist();
    notifyListeners();
  }

  SaxScaleProgress getScaleProgress(String scaleId, String rootKey) {
    final key = '$scaleId::$rootKey';
    return _scaleProgress[key] ??
        SaxScaleProgress(
          scaleId: scaleId,
          rootKey: rootKey,
          achievedBpm: 80,
          targetBpm: 120,
          masteryLevel: 0,
          updatedAt: DateTime.now().toUtc(),
        );
  }

  Future<void> updateScaleProgress({
    required String scaleId,
    required String rootKey,
    int? achievedBpm,
    int? targetBpm,
    int? masteryLevel,
  }) async {
    final current = getScaleProgress(scaleId, rootKey);
    final updated = current.copyWith(
      achievedBpm: achievedBpm,
      targetBpm: targetBpm,
      masteryLevel: masteryLevel,
      updatedAt: DateTime.now().toUtc(),
    );
    _scaleProgress[updated.compositeKey] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> upsertItem(SaxPracticeItem item) async {
    final idx = _items.indexWhere((n) => n.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.insert(0, item);
    }
    if (!_folders.contains(item.folder)) {
      _folders.add(item.folder);
    }
    await _persist();
    notifyListeners();
  }

  Future<SaxPracticeItem> logMetronomePracticeSession({
    required int bpm,
    required String timeSignature,
    required int durationMinutes,
    String? scaleSummary,
  }) async {
    final now = DateTime.now().toUtc();
    final mins = durationMinutes < 1 ? 1 : durationMinutes;
    final title = scaleSummary != null && scaleSummary.isNotEmpty
        ? 'Practice Session: $scaleSummary @ $bpm BPM'
        : 'Metronome Shed Session ($bpm BPM, $timeSignature)';
    final item = SaxPracticeItem(
      id: 'session-${now.millisecondsSinceEpoch}',
      title: title,
      content:
          'Completed $mins min saxophone shed session on ${_selectedHorn.shortBadge} at $bpm BPM ($timeSignature).',
      folder: 'Daily Routine',
      horn: _selectedHorn,
      keySignature: _selectedHorn.transpositionKey,
      targetBpm: bpm,
      durationMinutes: mins,
      tags: const ['shed', 'metronome'],
      color: PracticeCardColor.brass,
      createdAt: now,
      updatedAt: now,
    );
    _items.insert(0, item);
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _folders.contains(trimmed)) return;
    _folders.add(trimmed);
    await _persist();
    notifyListeners();
  }

  Future<void> togglePin(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(
      isPinned: !_items[idx].isPinned,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(
      isFavorite: !_items[idx].isFavorite,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> toggleArchive(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(
      isArchived: !_items[idx].isArchived,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> moveToTrash(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(
      isTrashed: true,
      isPinned: false,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> restoreFromTrash(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(
      isTrashed: false,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deletePermanently(String id) async {
    _items.removeWhere((n) => n.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    _items.removeWhere((n) => n.isTrashed);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleChecklistItem(String itemId, String checkId) async {
    final idx = _items.indexWhere((n) => n.id == itemId);
    if (idx < 0) return;
    final item = _items[idx];
    final updatedChecklist = item.checklist
        .map((c) => c.id == checkId ? c.copyWith(isDone: !c.isDone) : c)
        .toList();
    _items[idx] = item.copyWith(
      checklist: updatedChecklist,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    notifyListeners();
  }

  String exportBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'sax_buddy',
      'schema': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'selectedHorn': _selectedHorn.name,
      'weeklyGoalMinutes': _weeklyGoalMinutes,
      'folders': _folders,
      'items': _items.map((n) => n.toJson()).toList(),
      'scaleProgress': _scaleProgress.values.map((s) => s.toJson()).toList(),
    });
  }

  Future<int> mergeBackupJson(String rawJson) async {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Backup JSON is empty.');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Sax Buddy backup format.');
    }

    final rawFolders = decoded['folders'];
    if (rawFolders is List) {
      for (final f in rawFolders) {
        final name = f.toString().trim();
        if (name.isNotEmpty && !_folders.contains(name)) {
          _folders.add(name);
        }
      }
    }

    final rawScales = decoded['scaleProgress'];
    if (rawScales is List) {
      for (final entry in rawScales.whereType<Map<String, dynamic>>()) {
        final incoming = SaxScaleProgress.fromJson(entry);
        final existing = _scaleProgress[incoming.compositeKey];
        if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
          _scaleProgress[incoming.compositeKey] = incoming;
        }
      }
    }

    final rawList = decoded['items'] ?? decoded['notes'];
    if (rawList is! List) {
      throw const FormatException('Backup JSON does not contain an items list.');
    }

    var mergedCount = 0;
    for (final rawItem in rawList.whereType<Map<String, dynamic>>()) {
      final incoming = SaxPracticeItem.fromJson(rawItem);
      if (incoming.id.isEmpty) continue;
      final existingIdx = _items.indexWhere((n) => n.id == incoming.id);
      if (existingIdx < 0) {
        _items.add(incoming);
        mergedCount++;
      } else if (incoming.updatedAt.isAfter(_items[existingIdx].updatedAt)) {
        _items[existingIdx] = incoming;
        mergedCount++;
      }
      if (!_folders.contains(incoming.folder)) {
        _folders.add(incoming.folder);
      }
    }

    await _persist();
    notifyListeners();
    return mergedCount;
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _items.clear();
    _folders
      ..clear()
      ..addAll(defaultFolders);
    _scaleProgress.clear();
    _selectedHorn = SaxHornType.alto;
    _weeklyGoalMinutes = 180;
    _initialized = false;
    await initialize();
  }

  static List<SaxFingeringEntry> get catalogFingerings =>
      SaxCatalogData.fingerings;
  static List<SaxScaleDefinition> get catalogScales => SaxCatalogData.scales;
}
