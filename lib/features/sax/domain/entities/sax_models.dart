import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

enum SaxHornType {
  alto('Alto Sax', 'Eb', -9, 'Warm, agile lead voice (Concert Eb3–A5+)'),
  tenor('Tenor Sax', 'Bb', -14, 'Rich, expressive jazz & soul voice (Concert Ab2–D5+)'),
  soprano('Soprano Sax', 'Bb', -2, 'Bright, lyrical upper voice (Concert Ab3–D6+)'),
  baritone('Baritone Sax', 'Eb', -21, 'Deep, resonant anchor voice (Concert Db2–A4+)');

  const SaxHornType(
    this.label,
    this.transpositionKey,
    this.concertSemitoneOffset,
    this.subtitle,
  );

  final String label;
  final String transpositionKey;
  final int concertSemitoneOffset;
  final String subtitle;

  String get shortBadge => '$label ($transpositionKey)';

  int toConcertMidi(int writtenMidi) => writtenMidi + concertSemitoneOffset;

  double toConcertHz(int writtenMidi, {double a4Hz = 440.0}) {
    final concertMidi = toConcertMidi(writtenMidi);
    return a4Hz * math.pow(2.0, (concertMidi - 69) / 12.0);
  }

  String toConcertNoteName(int writtenMidi) {
    final concertMidi = toConcertMidi(writtenMidi);
    return HornTransposer.midiToNoteName(concertMidi);
  }
}

enum SaxKeyId {
  oct('Oct', 'Octave Thumb Key'),
  frontF('Tf', 'Front F Auxiliary Key'),
  palmD('D', 'Left Palm D Key'),
  palmEb('Eb', 'Left Palm Eb Key'),
  palmF('F', 'Left Palm F Key'),
  lh1('1', 'Left Index (B)'),
  bis('Bis', 'Left Index Bis Bb'),
  lh2('2', 'Left Middle (A)'),
  lh3('3', 'Left Ring (G)'),
  gSharp('G#', 'Left Pinky G# Table'),
  lowCSharp('C#', 'Left Pinky Low C#'),
  lowB('B', 'Left Pinky Low B'),
  lowBb('Bb', 'Left Pinky Low Bb'),
  rh4('4', 'Right Index (F)'),
  rh5('5', 'Right Middle (E)'),
  rh6('6', 'Right Ring (D)'),
  sideTa('Ta', 'Right Side Bb (Ta)'),
  sideTc('Tc', 'Right Side C (Tc)'),
  sideTe('Te', 'Right High E (Te)'),
  highFSharp('F#', 'Right High F# Key'),
  sideFSharp('Tf#', 'Right Trill / Fork F#'),
  lowEb('Eb', 'Right Pinky Eb Roller'),
  lowC('C', 'Right Pinky Low C Roller');

  const SaxKeyId(this.shortLabel, this.description);
  final String shortLabel;
  final String description;
}

class SaxFingeringVariant {
  const SaxFingeringVariant({
    required this.label,
    required this.pressedKeys,
    required this.tip,
  });

  final String label;
  final Set<SaxKeyId> pressedKeys;
  final String tip;
}

class SaxFingeringEntry {
  const SaxFingeringEntry({
    required this.writtenNote,
    required this.enharmonicLabel,
    required this.midiNote,
    required this.register,
    required this.tendencyCents,
    required this.variants,
    required this.practiceDrill,
  });

  final String writtenNote;
  final String enharmonicLabel;
  final int midiNote;
  final String register;
  final int tendencyCents;
  final List<SaxFingeringVariant> variants;
  final String practiceDrill;

  String get displayName =>
      enharmonicLabel.isNotEmpty ? '$writtenNote / $enharmonicLabel' : writtenNote;

  String get tendencyDescription {
    if (tendencyCents == 0) return 'Balanced intonation center';
    if (tendencyCents > 0) {
      return '+$tendencyCents¢ sharp tendency — relax jaw & warm air stream';
    }
    return '$tendencyCents¢ flat tendency — firm corners & raise tongue ("ee")';
  }
}

class SaxScaleDefinition {
  const SaxScaleDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.semitoneIntervals,
    required this.degreeFormula,
    required this.chordSymbolSuffix,
    required this.improvisationTip,
  });

  final String id;
  final String name;
  final String category;
  final List<int> semitoneIntervals;
  final String degreeFormula;
  final String chordSymbolSuffix;
  final String improvisationTip;

  List<String> spellNotes(String rootKey) {
    final rootIndex = HornTransposer.pitchClassIndex(rootKey);
    final preferFlats = HornTransposer.prefersFlats(rootKey, id);
    return semitoneIntervals
        .map((offset) => HornTransposer.pitchClassName(
              (rootIndex + offset) % 12,
              preferFlats: preferFlats,
            ))
        .toList();
  }
}

class SaxScaleProgress {
  const SaxScaleProgress({
    required this.scaleId,
    required this.rootKey,
    this.achievedBpm = 80,
    this.targetBpm = 120,
    this.masteryLevel = 0,
    required this.updatedAt,
  });

  final String scaleId;
  final String rootKey;
  final int achievedBpm;
  final int targetBpm;
  final int masteryLevel; // 0: New, 1: Learning, 2: Solid, 3: Mastered
  final DateTime updatedAt;

  String get compositeKey => '$scaleId::$rootKey';

  String get masteryLabel => switch (masteryLevel) {
        1 => 'Learning',
        2 => 'Solid',
        3 => 'Mastered',
        _ => 'New',
      };

  SaxScaleProgress copyWith({
    int? achievedBpm,
    int? targetBpm,
    int? masteryLevel,
    DateTime? updatedAt,
  }) {
    return SaxScaleProgress(
      scaleId: scaleId,
      rootKey: rootKey,
      achievedBpm: achievedBpm ?? this.achievedBpm,
      targetBpm: targetBpm ?? this.targetBpm,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'scaleId': scaleId,
        'rootKey': rootKey,
        'achievedBpm': achievedBpm,
        'targetBpm': targetBpm,
        'masteryLevel': masteryLevel,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory SaxScaleProgress.fromJson(Map<String, dynamic> json) {
    return SaxScaleProgress(
      scaleId: (json['scaleId'] ?? 'major').toString(),
      rootKey: (json['rootKey'] ?? 'C').toString(),
      achievedBpm: (json['achievedBpm'] as num?)?.toInt() ?? 80,
      targetBpm: (json['targetBpm'] as num?)?.toInt() ?? 120,
      masteryLevel: ((json['masteryLevel'] as num?)?.toInt() ?? 0).clamp(0, 3),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class PracticeChecklistItem {
  const PracticeChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  final String id;
  final String text;
  final bool isDone;

  PracticeChecklistItem copyWith({
    String? id,
    String? text,
    bool? isDone,
  }) {
    return PracticeChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isDone': isDone,
      };

  factory PracticeChecklistItem.fromJson(Map<String, dynamic> json) {
    return PracticeChecklistItem(
      id: (json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      isDone: json['isDone'] == true,
    );
  }
}

enum PracticeCardColor {
  neutral('Default', Color(0xFF64748B), Color(0xFFF8FAFC), Color(0xFF1E293B)),
  brass('Gold Brass', Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFF3B2507)),
  emerald('Jazz Mint', Color(0xFF059669), Color(0xFFECFDF5), Color(0xFF0A2E23)),
  cobalt('Blue Note', Color(0xFF2563EB), Color(0xFFEFF6FF), Color(0xFF13254B)),
  crimson('Velvet Red', Color(0xFFE11D48), Color(0xFFFFF1F2), Color(0xFF3B121D)),
  violet('Midnight Jam', Color(0xFF7C3AED), Color(0xFFF5F3FF), Color(0xFF261447));

  const PracticeCardColor(
    this.label,
    this.accent,
    this.lightSurface,
    this.darkSurface,
  );

  final String label;
  final Color accent;
  final Color lightSurface;
  final Color darkSurface;

  Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;
}

class SaxPracticeItem {
  const SaxPracticeItem({
    required this.id,
    required this.title,
    this.content = '',
    this.folder = 'Daily Routine',
    this.horn = SaxHornType.alto,
    this.keySignature = 'C',
    this.targetBpm = 120,
    this.durationMinutes = 20,
    this.tags = const <String>[],
    this.checklist = const <PracticeChecklistItem>[],
    this.isChecklist = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.isLocked = false,
    this.color = PracticeCardColor.neutral,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String folder;
  final SaxHornType horn;
  final String keySignature;
  final int targetBpm;
  final int durationMinutes;
  final List<String> tags;
  final List<PracticeChecklistItem> checklist;
  final bool isChecklist;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isTrashed;
  final bool isLocked;
  final PracticeCardColor color;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get completedChecklistCount => checklist.where((c) => c.isDone).length;

  SaxPracticeItem copyWith({
    String? id,
    String? title,
    String? content,
    String? folder,
    SaxHornType? horn,
    String? keySignature,
    int? targetBpm,
    int? durationMinutes,
    List<String>? tags,
    List<PracticeChecklistItem>? checklist,
    bool? isChecklist,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isTrashed,
    bool? isLocked,
    PracticeCardColor? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaxPracticeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folder: folder ?? this.folder,
      horn: horn ?? this.horn,
      keySignature: keySignature ?? this.keySignature,
      targetBpm: targetBpm ?? this.targetBpm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tags: tags ?? this.tags,
      checklist: checklist ?? this.checklist,
      isChecklist: isChecklist ?? this.isChecklist,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      isLocked: isLocked ?? this.isLocked,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'folder': folder,
        'horn': horn.name,
        'keySignature': keySignature,
        'targetBpm': targetBpm,
        'durationMinutes': durationMinutes,
        'tags': tags,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'isChecklist': isChecklist,
        'isPinned': isPinned,
        'isFavorite': isFavorite,
        'isArchived': isArchived,
        'isTrashed': isTrashed,
        'isLocked': isLocked,
        'color': color.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory SaxPracticeItem.fromJson(Map<String, dynamic> json) {
    final hornName = (json['horn'] ?? 'alto').toString();
    final horn = SaxHornType.values.firstWhere(
      (h) => h.name == hornName,
      orElse: () => SaxHornType.alto,
    );
    final colorName = (json['color'] ?? 'neutral').toString();
    final color = PracticeCardColor.values.firstWhere(
      (c) => c.name == colorName,
      orElse: () => PracticeCardColor.neutral,
    );
    final rawChecklist = (json['checklist'] as List?) ?? const [];
    final rawTags = (json['tags'] as List?) ?? const [];
    return SaxPracticeItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      folder: (json['folder'] ?? 'Daily Routine').toString(),
      horn: horn,
      keySignature: (json['keySignature'] ?? 'C').toString(),
      targetBpm: (json['targetBpm'] as num?)?.toInt() ?? 120,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 20,
      tags: rawTags.map((e) => e.toString()).toList(),
      checklist: rawChecklist
          .whereType<Map<String, dynamic>>()
          .map(PracticeChecklistItem.fromJson)
          .toList(),
      isChecklist: json['isChecklist'] == true,
      isPinned: json['isPinned'] == true,
      isFavorite: json['isFavorite'] == true,
      isArchived: json['isArchived'] == true,
      isTrashed: json['isTrashed'] == true,
      isLocked: json['isLocked'] == true,
      color: color,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

enum TranspositionSystem {
  concert('Concert Pitch (C)', 'Piano / Guitar / Flute / C Lead Sheet', 0),
  eb('Eb Saxophone (Alto / Baritone)', 'Written a Major 6th higher (+9 semitones)', 9),
  bb('Bb Saxophone (Tenor / Soprano)', 'Written a Major 2nd higher (+2 semitones)', 2);

  const TranspositionSystem(
    this.label,
    this.subtitle,
    this.semitonesAboveConcert,
  );

  final String label;
  final String subtitle;
  final int semitonesAboveConcert;
}

class HornTransposer {
  static const List<String> sharpNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const List<String> flatNames = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static const List<String> circleKeys = [
    'C',
    'F',
    'Bb',
    'Eb',
    'Ab',
    'Db',
    'Gb',
    'B',
    'E',
    'A',
    'D',
    'G',
  ];

  static int pitchClassIndex(String rawNote) {
    final cleaned = rawNote.trim();
    if (cleaned.isEmpty) return 0;
    final match = RegExp(r'^([A-Ga-g])([#b♯♭]?)').firstMatch(cleaned);
    if (match == null) return 0;
    final letter = match.group(1)!.toUpperCase();
    final accidental = match.group(2) ?? '';
    final base = switch (letter) {
      'C' => 0,
      'D' => 2,
      'E' => 4,
      'F' => 5,
      'G' => 7,
      'A' => 9,
      'B' => 11,
      _ => 0,
    };
    final offset = switch (accidental) {
      '#' || '♯' => 1,
      'b' || '♭' => -1,
      _ => 0,
    };
    return (base + offset + 12) % 12;
  }

  static bool prefersFlats(String rootKey, [String scaleId = '']) {
    const flatRoots = {'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb', 'Cb'};
    if (flatRoots.contains(rootKey)) return true;
    if (scaleId.contains('minor') ||
        scaleId.contains('dorian') ||
        scaleId.contains('blues')) {
      return !{'G', 'D', 'A', 'E', 'B', 'F#'}.contains(rootKey);
    }
    return false;
  }

  static String pitchClassName(int index, {bool preferFlats = true}) {
    final norm = ((index % 12) + 12) % 12;
    return preferFlats ? flatNames[norm] : sharpNames[norm];
  }

  static String midiToNoteName(int midi, {bool preferFlats = true}) {
    final octave = (midi ~/ 12) - 1;
    final pc = pitchClassName(midi % 12, preferFlats: preferFlats);
    return '$pc$octave';
  }

  /// Transposes a single note or chord token (including slash chords like `Dm7b5/Ab`)
  /// by [semitoneDelta] semitones.
  static String transposeToken(
    String token,
    int semitoneDelta, {
    bool preferFlats = true,
  }) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return token;

    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 2 &&
          RegExp(r'^[A-Ga-g][#b♯♭]?').hasMatch(parts[0]) &&
          RegExp(r'^[A-Ga-g][#b♯♭]?$').hasMatch(parts[1])) {
        final left = transposeToken(parts[0], semitoneDelta, preferFlats: preferFlats);
        final right = transposeToken(parts[1], semitoneDelta, preferFlats: preferFlats);
        return '$left/$right';
      }
    }

    final match = RegExp(r'^([A-G])([#b♯♭]?)(.*)$').firstMatch(trimmed);
    if (match == null) return token;
    final root = '${match.group(1)}${match.group(2)}';
    final suffix = match.group(3) ?? '';
    final oldPc = pitchClassIndex(root);
    final newPc = (oldPc + semitoneDelta + 120) % 12;
    final newRoot = pitchClassName(newPc, preferFlats: preferFlats);
    return '$newRoot$suffix';
  }

  /// Transposes an entire chord chart or melody line from [from] to [to].
  static String transposeChart(
    String input, {
    required TranspositionSystem from,
    required TranspositionSystem to,
    bool? preferFlatsOverride,
  }) {
    final delta = to.semitonesAboveConcert - from.semitonesAboveConcert;
    if (delta == 0) return input;
    final preferFlats = preferFlatsOverride ?? (to != TranspositionSystem.concert);

    return input.replaceAllMapped(
      RegExp(
        r'\b([A-G][#b♯♭]?(?:Maj|Min|maj|min|m|M|dim|aug|sus|add|alt|[0-9+#b\-])*)(/[A-G][#b♯♭]?)?(?=\s|\||$|-|,|\))',
      ),
      (m) => transposeToken(m.group(0)!, delta, preferFlats: preferFlats),
    );
  }
}
