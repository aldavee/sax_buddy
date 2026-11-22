import 'package:flutter_test/flutter_test.dart';
import 'package:sax_buddy/features/app_update/data/app_update_service.dart';
import 'package:sax_buddy/features/sax/data/sax_catalog_data.dart';
import 'package:sax_buddy/features/sax/data/sax_repository.dart';
import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SaxRepository.instance.resetForTest();
  });

  test('SaxRepository seeds starter routines and supports CRUD + trash',
      () async {
    final repo = SaxRepository.instance;
    expect(repo.activeItems.length, greaterThanOrEqualTo(3));

    final now = DateTime.now().toUtc();
    final item = SaxPracticeItem(
      id: 'test-sax-1',
      title: 'Giant Steps Coltrane Changes',
      content: 'BMaj7 D7 | GMaj7 Bb7 | EbMaj7 | Am7 D7 |',
      folder: 'Repertoire',
      horn: SaxHornType.tenor,
      keySignature: 'B',
      targetBpm: 220,
      durationMinutes: 35,
      tags: const ['coltrane', 'changes'],
      createdAt: now,
      updatedAt: now,
    );
    await repo.upsertItem(item);
    expect(
      repo.activeItems.any((n) => n.id == 'test-sax-1'),
      isTrue,
    );

    await repo.moveToTrash('test-sax-1');
    expect(repo.activeItems.any((n) => n.id == 'test-sax-1'), isFalse);
    expect(repo.trashedItems.any((n) => n.id == 'test-sax-1'), isTrue);

    await repo.restoreFromTrash('test-sax-1');
    expect(repo.activeItems.any((n) => n.id == 'test-sax-1'), isTrue);

    await repo.deletePermanently('test-sax-1');
    expect(repo.allItems.any((n) => n.id == 'test-sax-1'), isFalse);
  });

  test('SaxRepository merges backup JSON using latest updatedAt', () async {
    final repo = SaxRepository.instance;
    final exported = repo.exportBackupJson();

    final count = await repo.mergeBackupJson(exported);
    expect(count, 0);
  });

  test('HornTransposer and SaxCatalogData transpose and spell notes accurately',
      () {
    // Concert C -> Eb Alto (+9 semitones = A)
    final altoChart = HornTransposer.transposeChart(
      'Cm7 F7 BbMaj7',
      from: TranspositionSystem.concert,
      to: TranspositionSystem.eb,
    );
    expect(altoChart, 'Am7 D7 GMaj7');

    // Concert C -> Bb Tenor (+2 semitones = D)
    final tenorChart = HornTransposer.transposeChart(
      'Cm7 F7 BbMaj7',
      from: TranspositionSystem.concert,
      to: TranspositionSystem.bb,
    );
    expect(tenorChart, 'Dm7 G7 CMaj7');

    // Written F#5 (midi 78) on Alto Sax (-9) = Concert A4 (midi 69, 440.0 Hz)
    expect(SaxHornType.alto.toConcertNoteName(78), 'A4');
    expect(SaxHornType.alto.toConcertHz(78), closeTo(440.0, 0.05));

    expect(SaxCatalogData.fingerings.length, greaterThanOrEqualTo(35));
    expect(SaxCatalogData.scales.length, greaterThanOrEqualTo(12));
  });

  test('AppUpdateService.compareVersions compares semver + build correctly',
      () {
    expect(AppUpdateService.compareVersions('1.0.0+2', '1.0.0+1'), 1);
    expect(AppUpdateService.compareVersions('1.0.0+1', '1.0.0+1'), 0);
    expect(AppUpdateService.compareVersions('1.1.0+1', '1.0.9+99'), 1);
  });
}
