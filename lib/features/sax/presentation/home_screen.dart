import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sax_buddy/core/presentation/navigation/adaptive_page_route.dart';
import 'package:sax_buddy/core/presentation/widgets/adaptive_overlay.dart';
import 'package:sax_buddy/core/presentation/widgets/app_snackbar.dart';
import 'package:sax_buddy/core/theme/theme_service.dart';
import 'package:sax_buddy/features/app_update/presentation/app_version_checker_card.dart';
import 'package:sax_buddy/features/drive_sync/data/sax_drive_sync_service.dart';
import 'package:sax_buddy/features/sax/data/sax_catalog_data.dart';
import 'package:sax_buddy/features/sax/data/sax_repository.dart';
import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';
import 'package:sax_buddy/features/sax/presentation/pages/practice_item_editor_page.dart';
import 'package:sax_buddy/features/sax/presentation/widgets/sax_fingering_diagram.dart';
import 'package:sax_buddy/features/security/data/biometric_service.dart';
import 'package:sax_buddy/features/security/presentation/biometric_lock_gate.dart';

enum _SaxHubTab {
  studio('Practice Studio', Icons.library_music_outlined, Icons.library_music_rounded),
  fingerings('Fingering Chart', Icons.piano_outlined, Icons.piano_rounded),
  metronome('Metronome & Drone', Icons.av_timer_outlined, Icons.av_timer_rounded),
  scales('Scales & Jazz', Icons.auto_graph_outlined, Icons.auto_graph_rounded),
  transposer('Transposer', Icons.swap_horiz_rounded, Icons.swap_horizontal_circle_rounded);

  const _SaxHubTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

enum _StudioFilter {
  all('All Entries'),
  favorites('Favorites'),
  checklists('Checklists'),
  archived('Archive'),
  trash('Trash');

  const _StudioFilter(this.label);
  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SaxRepository _repo = SaxRepository.instance;
  final SaxDriveSyncService _driveSync = SaxDriveSyncService.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  _SaxHubTab _tab = _SaxHubTab.studio;
  _StudioFilter _studioFilter = _StudioFilter.all;
  String? _selectedFolder;
  String? _selectedTag;
  bool _isGrid = true;
  bool _isSyncing = false;

  // Fingering Chart state
  String _selectedRegister = 'All';
  int _selectedFingeringIndex = 11; // A4 default
  int _selectedVariantIndex = 0;

  // Metronome & Drone state
  int _bpm = 112;
  int _beatsPerBar = 4;
  int _currentBeat = 0;
  bool _metronomePlaying = false;
  bool _jazzBackbeat2and4 = false;
  String _droneNote = 'Bb';
  bool _droneActive = false;
  Timer? _metronomeTimer;
  Timer? _sessionClockTimer;
  int _elapsedSessionSeconds = 0;
  final List<DateTime> _tapTimes = <DateTime>[];

  // Scales & Jazz Trainer state
  String _selectedScaleRoot = 'C';
  String _selectedScaleCategory = 'All';
  String _selectedScaleId = 'major';

  // Transposer state
  TranspositionSystem _transposeFrom = TranspositionSystem.concert;
  TranspositionSystem _transposeTo = TranspositionSystem.eb;
  late final TextEditingController _transposerInputCtrl = TextEditingController(
    text: '| Cm7 | F7 | BbMaj7 | EbMaj7 |\n| Am7b5 | D7b9 | Gm7 | G7alt |',
  );

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChanged);
    _driveSync.addListener(_onChanged);
    _repo.initialize();
    _driveSync.initialize();
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _sessionClockTimer?.cancel();
    _repo.removeListener(_onChanged);
    _driveSync.removeListener(_onChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _transposerInputCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _toggleMetronome() {
    if (_metronomePlaying) {
      _metronomeTimer?.cancel();
      _sessionClockTimer?.cancel();
      setState(() {
        _metronomePlaying = false;
        _currentBeat = 0;
      });
    } else {
      setState(() {
        _metronomePlaying = true;
        _currentBeat = 1;
      });
      _scheduleMetronomeLoop();
      _sessionClockTimer?.cancel();
      _sessionClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _metronomePlaying) {
          setState(() => _elapsedSessionSeconds++);
        }
      });
    }
  }

  void _scheduleMetronomeLoop() {
    _metronomeTimer?.cancel();
    if (!_metronomePlaying) return;
    final intervalMs = (60000 / _bpm).round().clamp(180, 2000);
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted || !_metronomePlaying) return;
      SystemSound.play(SystemSoundType.click);
      setState(() {
        _currentBeat = (_currentBeat % _beatsPerBar) + 1;
      });
    });
  }

  void _updateBpm(int nextBpm) {
    final clamped = nextBpm.clamp(30, 260);
    setState(() => _bpm = clamped);
    if (_metronomePlaying) {
      _scheduleMetronomeLoop();
    }
  }

  void _handleTapTempo() {
    final now = DateTime.now();
    _tapTimes.removeWhere((t) => now.difference(t).inMilliseconds > 2500);
    _tapTimes.add(now);
    if (_tapTimes.length >= 2) {
      var totalMs = 0;
      for (var i = 1; i < _tapTimes.length; i++) {
        totalMs += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
      }
      final avgMs = totalMs / (_tapTimes.length - 1);
      if (avgMs > 0) {
        _updateBpm((60000 / avgMs).round());
      }
    }
  }

  List<SaxPracticeItem> _filteredItems() {
    var base = switch (_studioFilter) {
      _StudioFilter.all => _repo.activeItems,
      _StudioFilter.favorites => _repo.favoriteItems,
      _StudioFilter.checklists => _repo.checklistItems,
      _StudioFilter.archived => _repo.archivedItems,
      _StudioFilter.trash => _repo.trashedItems,
    };

    if (_selectedFolder != null) {
      base = base.where((n) => n.folder == _selectedFolder).toList();
    }
    if (_selectedTag != null) {
      base = base.where((n) => n.tags.contains(_selectedTag)).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      base = base.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query) ||
            n.folder.toLowerCase().contains(query) ||
            n.keySignature.toLowerCase().contains(query) ||
            n.tags.any((t) => t.toLowerCase().contains(query)) ||
            n.checklist.any((c) => c.text.toLowerCase().contains(query));
      }).toList();
    }
    return base;
  }

  Future<void> _openEditor({
    SaxPracticeItem? item,
    bool isChecklist = false,
  }) async {
    if (item != null && item.isLocked && BiometricService.instance.isSupported) {
      final auth = await BiometricService.instance.authenticate(
        reason: 'Authenticate to open locked practice entry',
      );
      if (!auth.success) {
        if (mounted) {
          AppSnackBar.show(
            context,
            auth.errorMessage ?? 'Authentication required',
            backgroundColor: Theme.of(context).colorScheme.error,
          );
        }
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      adaptivePageRoute(
        context,
        builder: (_) => PracticeItemEditorPage(
          initialItem: item,
          initialChecklist: isChecklist,
          defaultFolder: _selectedFolder ?? 'Daily Routine',
        ),
      ),
    );
  }

  Future<void> _syncWithDrive() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      if (!_driveSync.isSignedIn) {
        final ok = await _driveSync.signIn();
        if (!ok) return;
      }
      final remoteJson = await _driveSync.downloadBackupJson();
      var merged = 0;
      if (remoteJson != null && remoteJson.trim().isNotEmpty) {
        merged = await _repo.mergeBackupJson(remoteJson);
      }
      await _driveSync.uploadBackupJson(_repo.exportBackupJson());
      if (mounted) {
        AppSnackBar.show(
          context,
          merged > 0
              ? 'Synced with Google Drive ($merged updated)'
              : 'Sax Buddy Studio backed up to Google Drive',
          icon: Icons.cloud_done_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          AppSnackBar.sanitizeError(e),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Studio Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. Bebop Etudes, Gig Setlist, Altissimo Lab',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await _repo.addFolder(name.trim());
      setState(() => _selectedFolder = name.trim());
    }
  }

  Future<void> _showBackupSheet() async {
    final jsonCtrl = TextEditingController();
    await showAdaptiveDialogOrSheet<void>(
      context: context,
      maxWidth: 540,
      desktopTitle: 'Backup, Google Drive & Updates',
      desktopIcon: Icons.cloud_sync_rounded,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    _driveSync.isSignedIn
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_outlined,
                  ),
                ),
                title: Text(
                  _driveSync.isSignedIn
                      ? _driveSync.profile?.displayName ?? 'Google Account'
                      : 'Google Drive Sync',
                ),
                subtitle: Text(
                  _driveSync.isSignedIn
                      ? _driveSync.profile?.email ?? 'Connected'
                      : 'Back up & merge practice logs, repertoire & scale mastery',
                ),
                trailing: _driveSync.isSignedIn
                    ? TextButton(
                        onPressed: () async {
                          await _driveSync.signOut();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text('Sign out'),
                      )
                    : FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _syncWithDrive();
                        },
                        child: const Text('Connect'),
                      ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _repo.exportBackupJson()),
                      );
                      if (ctx.mounted) {
                        AppSnackBar.show(
                          ctx,
                          'JSON backup copied to clipboard',
                          icon: Icons.copy_rounded,
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Copy JSON Backup'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _syncWithDrive();
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sync Drive Now'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Restore / Merge from JSON Backup',
                  hintText: 'Paste exported Sax Buddy JSON here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final count = await _repo.mergeBackupJson(jsonCtrl.text);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        AppSnackBar.show(
                          context,
                          'Merged $count item(s) from backup',
                          icon: Icons.check_circle_outline,
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        AppSnackBar.show(
                          ctx,
                          AppSnackBar.sanitizeError(e),
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                        );
                      }
                    }
                  },
                  child: const Text('Import & Merge'),
                ),
              ),
              const Divider(height: 28),
              const AppVersionCheckerCard(autoCheckOnInit: true),
            ],
          ),
        ),
      ),
    );
    jsonCtrl.dispose();
  }

  Widget _buildHornSelectorChip(ColorScheme cs) {
    return PopupMenuButton<SaxHornType>(
      tooltip: 'Active Saxophone Horn',
      onSelected: _repo.setSelectedHorn,
      itemBuilder: (_) => SaxHornType.values
          .map(
            (h) => PopupMenuItem(
              value: h,
              child: Row(
                children: [
                  Icon(
                    _repo.selectedHorn == h
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(h.shortBadge)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, size: 16, color: cs.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              _repo.selectedHorn.shortBadge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioTab(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = _filteredItems();
    final progressRatio =
        (_repo.totalPracticeMinutes / _repo.weeklyGoalMinutes).clamp(0.0, 1.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Shed Goal: ${_repo.totalPracticeMinutes} / ${_repo.weeklyGoalMinutes} min • ${_repo.masteredScalesCount} Scales Mastered • Avg ${_repo.averageTargetBpm} BPM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDesktop) ...[
                  const SizedBox(width: 8),
                  _buildHornSelectorChip(cs),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search routines, repertoire tunes, #tags, keys...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (_studioFilter == _StudioFilter.trash && items.isNotEmpty) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _repo.emptyTrash,
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Empty Trash'),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ..._StudioFilter.values.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: _studioFilter == f,
                    onSelected: (_) => setState(() => _studioFilter = f),
                  ),
                ),
              ),
              const VerticalDivider(width: 16),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('All Folders'),
                  selected: _selectedFolder == null,
                  onSelected: (_) => setState(() => _selectedFolder = null),
                ),
              ),
              ..._repo.folders.map(
                (folder) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(folder),
                    selected: _selectedFolder == folder,
                    onSelected: (sel) =>
                        setState(() => _selectedFolder = sel ? folder : null),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('Folder'),
                  onPressed: _showCreateFolderDialog,
                ),
              ),
              ..._repo.allTags.map(
                (tag) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('#$tag'),
                    selected: _selectedTag == tag,
                    onSelected: (sel) =>
                        setState(() => _selectedTag = sel ? tag : null),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 52,
                          color: cs.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No practice routines or repertoire charts match',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openEditor(
                            isChecklist:
                                _studioFilter == _StudioFilter.checklists,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New Practice Routine'),
                        ),
                      ],
                    ),
                  ),
                )
              : _isGrid
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 350,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _PracticeCard(
                        item: items[i],
                        onTap: () => _openEditor(item: items[i]),
                        onTogglePin: () => _repo.togglePin(items[i].id),
                        onToggleArchive: () => _repo.toggleArchive(items[i].id),
                        onTrashOrRestore: () => items[i].isTrashed
                            ? _repo.restoreFromTrash(items[i].id)
                            : _repo.moveToTrash(items[i].id),
                        onDeleteForever: () =>
                            _repo.deletePermanently(items[i].id),
                        onToggleChecklistItem: (stepId) =>
                            _repo.toggleChecklistItem(items[i].id, stepId),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _PracticeCard(
                        item: items[i],
                        compactList: true,
                        onTap: () => _openEditor(item: items[i]),
                        onTogglePin: () => _repo.togglePin(items[i].id),
                        onToggleArchive: () => _repo.toggleArchive(items[i].id),
                        onTrashOrRestore: () => items[i].isTrashed
                            ? _repo.restoreFromTrash(items[i].id)
                            : _repo.moveToTrash(items[i].id),
                        onDeleteForever: () =>
                            _repo.deletePermanently(items[i].id),
                        onToggleChecklistItem: (stepId) =>
                            _repo.toggleChecklistItem(items[i].id, stepId),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFingeringChartTab(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allFingerings = SaxCatalogData.fingerings;
    final registers = ['All', 'Low', 'Middle', 'High', 'Palm', 'Altissimo'];
    final filtered = _selectedRegister == 'All'
        ? allFingerings
        : allFingerings.where((f) => f.register == _selectedRegister).toList();

    final current = allFingerings[
        _selectedFingeringIndex.clamp(0, allFingerings.length - 1)];
    final variantIdx =
        _selectedVariantIndex.clamp(0, current.variants.length - 1);
    final variant = current.variants[variantIdx];
    final horn = _repo.selectedHorn;
    final concertNote = horn.toConcertNoteName(current.midiNote);
    final concertHz = horn.toConcertHz(current.midiNote);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: registers
              .map(
                (reg) => ChoiceChip(
                  label: Text(reg),
                  selected: _selectedRegister == reg,
                  onSelected: (_) => setState(() => _selectedRegister = reg),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final entry = filtered[i];
              final globalIdx = allFingerings.indexOf(entry);
              final selected = globalIdx == _selectedFingeringIndex;
              return ChoiceChip(
                label: Text(
                  entry.writtenNote,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                selected: selected,
                onSelected: (_) => setState(() {
                  _selectedFingeringIndex = globalIdx;
                  _selectedVariantIndex = 0;
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth >= 680;
            final diagram = SaxFingeringDiagram(
              pressedKeys: variant.pressedKeys,
              height: 360,
            );
            final details = Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Written: ${current.displayName}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Chip(label: Text('${current.register} Register')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${horn.shortBadge} → Concert Pitch: $concertNote (${concertHz.toStringAsFixed(1)} Hz)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (current.variants.length > 1) ...[
                      Text(
                        'Alternate Fingerings:',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(current.variants.length, (idx) {
                          return ChoiceChip(
                            label: Text(current.variants[idx].label),
                            selected: idx == variantIdx,
                            onSelected: (_) =>
                                setState(() => _selectedVariantIndex = idx),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        'Fingering: ${variant.label}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Pressed Keys: ${variant.pressedKeys.isEmpty ? "Open (No keys pressed)" : variant.pressedKeys.map((k) => k.shortLabel).join(" + ")}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Divider(height: 24),
                    Text(
                      'Voicing & Technique Tip',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(variant.tip),
                    const SizedBox(height: 12),
                    Text(
                      'Intonation Tendency',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(current.tendencyDescription),
                    const SizedBox(height: 12),
                    Text(
                      'Recommended Shed Drill',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(current.practiceDrill),
                  ],
                ),
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: diagram),
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                diagram,
                const SizedBox(height: 14),
                details,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetronomeTab(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mins = _elapsedSessionSeconds ~/ 60;
    final secs = (_elapsedSessionSeconds % 60).toString().padLeft(2, '0');
    final tempoMarking = _bpm < 60
        ? 'Largo'
        : _bpm < 76
            ? 'Adagio'
            : _bpm < 108
                ? 'Andante'
                : _bpm < 120
                    ? 'Moderato'
                    : _bpm < 168
                        ? 'Allegro'
                        : 'Presto / Bebop';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '$_bpm BPM',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '$tempoMarking • $_beatsPerBar/4 Time${_jazzBackbeat2and4 ? " • Jazz 2 & 4 Backbeat Lock" : ""}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_beatsPerBar, (index) {
                        final beatNum = index + 1;
                        final isCurrent =
                            _metronomePlaying && _currentBeat == beatNum;
                        final isAccent = _jazzBackbeat2and4
                            ? (beatNum == 2 || beatNum == 4)
                            : (beatNum == 1);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 110),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: isCurrent ? 38 : 30,
                          height: isCurrent ? 38 : 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? (isAccent ? Colors.amber.shade700 : cs.primary)
                                : cs.surfaceContainerHighest,
                            border: Border.all(
                              color: isAccent ? Colors.amber.shade700 : cs.outline,
                              width: isAccent ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$beatNum',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : cs.onSurface,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    Slider(
                      value: _bpm.toDouble(),
                      min: 30,
                      max: 260,
                      divisions: 230,
                      onChanged: (v) => _updateBpm(v.round()),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => _updateBpm(_bpm - 5),
                          child: const Text('-5'),
                        ),
                        OutlinedButton(
                          onPressed: () => _updateBpm(_bpm - 1),
                          child: const Text('-1'),
                        ),
                        FilledButton.icon(
                          onPressed: _toggleMetronome,
                          icon: Icon(
                            _metronomePlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(_metronomePlaying ? 'Stop' : 'Start'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _handleTapTempo,
                          icon: const Icon(Icons.touch_app_rounded, size: 18),
                          label: const Text('Tap Tempo'),
                        ),
                        OutlinedButton(
                          onPressed: () => _updateBpm(_bpm + 1),
                          child: const Text('+1'),
                        ),
                        OutlinedButton(
                          onPressed: () => _updateBpm(_bpm + 5),
                          child: const Text('+5'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final beats in [2, 3, 4, 5, 6, 7])
                          ChoiceChip(
                            label: Text('$beats/4'),
                            selected: _beatsPerBar == beats,
                            onSelected: (_) =>
                                setState(() => _beatsPerBar = beats),
                          ),
                        FilterChip(
                          label: const Text('Jazz 2 & 4 Backbeat'),
                          selected: _jazzBackbeat2and4,
                          onSelected: (v) =>
                              setState(() => _jazzBackbeat2and4 = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Concert Reference Pitch & Long-Tone Drone ($mins:$secs elapsed)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final loggedMins =
                                (_elapsedSessionSeconds / 60).ceil().clamp(1, 180);
                            await _repo.logMetronomePracticeSession(
                              bpm: _bpm,
                              timeSignature: '$_beatsPerBar/4',
                              durationMinutes: loggedMins,
                            );
                            setState(() => _elapsedSessionSeconds = 0);
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                'Logged $loggedMins min session @ $_bpm BPM to Practice Studio',
                                icon: Icons.check_circle_outline,
                              );
                            }
                          },
                          icon: const Icon(Icons.playlist_add_check_rounded),
                          label: const Text('Log Session to Studio'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: HornTransposer.circleKeys.map((note) {
                        return ChoiceChip(
                          label: Text(note),
                          selected: _droneNote == note,
                          onSelected: (_) => setState(() => _droneNote = note),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Reference Drone Cell: Concert $_droneNote (${_repo.selectedHorn.shortBadge} written ${HornTransposer.transposeToken(_droneNote, -_repo.selectedHorn.concertSemitoneOffset)})',
                      ),
                      subtitle: const Text(
                        'Hold steady air column and match overtone beats against the reference pitch center',
                      ),
                      value: _droneActive,
                      onChanged: (v) {
                        SystemSound.play(SystemSoundType.click);
                        setState(() => _droneActive = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScalesTab(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categories = [
      'All',
      'Fundamental',
      'Jazz Modes',
      'Bebop & Blues',
      'Arpeggios & Patterns',
    ];
    final scales = _selectedScaleCategory == 'All'
        ? SaxCatalogData.scales
        : SaxCatalogData.scales
            .where((s) => s.category == _selectedScaleCategory)
            .toList();

    final currentScale = scales.firstWhere(
      (s) => s.id == _selectedScaleId,
      orElse: () => scales.first,
    );
    final spelledNotes = currentScale.spellNotes(_selectedScaleRoot);
    final progress =
        _repo.getScaleProgress(currentScale.id, _selectedScaleRoot);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Root Key (Written for ${_repo.selectedHorn.shortBadge})',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: HornTransposer.circleKeys
              .map(
                (k) => ChoiceChip(
                  label: Text(k),
                  selected: _selectedScaleRoot == k,
                  onSelected: (_) => setState(() => _selectedScaleRoot = k),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories
              .map(
                (cat) => FilterChip(
                  label: Text(cat),
                  selected: _selectedScaleCategory == cat,
                  onSelected: (_) => setState(() {
                    _selectedScaleCategory = cat;
                    final firstMatch = cat == 'All'
                        ? SaxCatalogData.scales.first
                        : SaxCatalogData.scales
                            .firstWhere((s) => s.category == cat);
                    _selectedScaleId = firstMatch.id;
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: scales
              .map(
                (s) => ChoiceChip(
                  label: Text(s.name),
                  selected: currentScale.id == s.id,
                  onSelected: (_) => setState(() => _selectedScaleId = s.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_selectedScaleRoot ${currentScale.name} ($_selectedScaleRoot${currentScale.chordSymbolSuffix})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        _updateBpm(progress.achievedBpm);
                        setState(() => _tab = _SaxHubTab.metronome);
                      },
                      icon: const Icon(Icons.av_timer_rounded, size: 18),
                      label: Text('Shed @ ${progress.achievedBpm} BPM'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Formula: ${currentScale.degreeFormula} • Concert Root: ${HornTransposer.transposeToken(_selectedScaleRoot, _repo.selectedHorn.concertSemitoneOffset)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: spelledNotes.map((note) {
                    final fingering =
                        SaxCatalogData.fingeringForPitchClass(note);
                    final keysText = fingering.variants.first.pressedKeys.isEmpty
                        ? 'Open'
                        : fingering.variants.first.pressedKeys
                            .map((k) => k.shortLabel)
                            .join('+');
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final idx =
                            SaxCatalogData.fingerings.indexOf(fingering);
                        setState(() {
                          if (idx >= 0) _selectedFingeringIndex = idx;
                          _tab = _SaxHubTab.fingerings;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              note,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              keysText,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(currentScale.improvisationTip),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      'Mastery: ${progress.masteryLabel} (${progress.achievedBpm} BPM)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    for (var lvl = 0; lvl <= 3; lvl++)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(
                            switch (lvl) {
                              1 => 'Learning',
                              2 => 'Solid',
                              3 => 'Mastered',
                              _ => 'New',
                            },
                          ),
                          selected: progress.masteryLevel == lvl,
                          onSelected: (_) => _repo.updateScaleProgress(
                            scaleId: currentScale.id,
                            rootKey: _selectedScaleRoot,
                            masteryLevel: lvl,
                          ),
                        ),
                      ),
                  ],
                ),
                Slider(
                  value: progress.achievedBpm.clamp(40, 240).toDouble(),
                  min: 40,
                  max: 240,
                  divisions: 200,
                  label: '${progress.achievedBpm} BPM',
                  onChanged: (v) => _repo.updateScaleProgress(
                    scaleId: currentScale.id,
                    rootKey: _selectedScaleRoot,
                    achievedBpm: v.round(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransposerTab(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final transposed = HornTransposer.transposeChart(
      _transposerInputCtrl.text,
      from: _transposeFrom,
      to: _transposeTo,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Smart Horn Transposer (Concert C ↔ Eb Alto/Bari ↔ Bb Tenor/Soprano)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<TranspositionSystem>(
                          value: _transposeFrom,
                          items: TranspositionSystem.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('From: ${s.label}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _transposeFrom = v);
                          },
                        ),
                        IconButton(
                          tooltip: 'Swap directions',
                          icon: const Icon(Icons.swap_horiz_rounded),
                          onPressed: () => setState(() {
                            final tmp = _transposeFrom;
                            _transposeFrom = _transposeTo;
                            _transposeTo = tmp;
                          }),
                        ),
                        DropdownButton<TranspositionSystem>(
                          value: _transposeTo,
                          items: TranspositionSystem.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('To: ${s.label}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _transposeTo = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _transposerInputCtrl,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Source Chord Changes or Melody Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transposed Output (${_transposeTo.label}):',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            transposed,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: transposed),
                            );
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                'Transposed chart copied to clipboard',
                                icon: Icons.copy_rounded,
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy Transposed Chart'),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final now = DateTime.now().toUtc();
                            await _repo.upsertItem(
                              SaxPracticeItem(
                                id: 'chart-${now.millisecondsSinceEpoch}',
                                title:
                                    'Transposed Chart (${_transposeTo.label})',
                                content: transposed,
                                folder: 'Repertoire',
                                horn: _transposeTo == TranspositionSystem.bb
                                    ? SaxHornType.tenor
                                    : SaxHornType.alto,
                                tags: const ['transposed', 'repertoire'],
                                color: PracticeCardColor.cobalt,
                                createdAt: now,
                                updatedAt: now,
                              ),
                            );
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                'Saved transposed chart to Repertoire folder',
                                icon: Icons.library_add_check_rounded,
                              );
                            }
                          },
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text('Save to Repertoire'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = isDesktopLayoutContext(context);

    final activeBody = switch (_tab) {
      _SaxHubTab.studio => _buildStudioTab(context, isDesktop),
      _SaxHubTab.fingerings => _buildFingeringChartTab(context),
      _SaxHubTab.metronome => _buildMetronomeTab(context),
      _SaxHubTab.scales => _buildScalesTab(context),
      _SaxHubTab.transposer => _buildTransposerTab(context),
    };

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _openEditor(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          setState(() => _tab = _SaxHubTab.studio);
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.f5): _syncWithDrive,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: isDesktop ? 20 : 8,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: cs.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Sax Buddy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 10),
                  _buildHornSelectorChip(cs),
                ],
              ],
            ),
            actions: [
              if (_tab == _SaxHubTab.studio)
                IconButton(
                  visualDensity: isDesktop ? null : VisualDensity.compact,
                  tooltip: _isGrid ? 'List view' : 'Grid view',
                  icon: Icon(
                    _isGrid
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                  ),
                  onPressed: () => setState(() => _isGrid = !_isGrid),
                ),
              IconButton(
                visualDensity: isDesktop ? null : VisualDensity.compact,
                tooltip: 'Sync with Google Drive (F5)',
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _driveSync.isSignedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_sync_outlined,
                      ),
                onPressed: _isSyncing ? null : _syncWithDrive,
              ),
              IconButton(
                visualDensity: isDesktop ? null : VisualDensity.compact,
                tooltip: 'Theme: ${ThemeService.instance.modeLabel}',
                icon: Icon(ThemeService.instance.modeIcon),
                onPressed: () => ThemeService.instance.cycleThemeMode(),
              ),
              IconButton(
                visualDensity: isDesktop ? null : VisualDensity.compact,
                tooltip: 'Security & App Lock',
                icon: const Icon(Icons.shield_outlined),
                onPressed: () => BiometricLockGate.showSettingsSheet(context),
              ),
              IconButton(
                visualDensity: isDesktop ? null : VisualDensity.compact,
                tooltip: 'Backup & Updates',
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showBackupSheet,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Row(
            children: [
              if (isDesktop)
                NavigationRail(
                  selectedIndex: _tab.index,
                  extended: MediaQuery.sizeOf(context).width >= 1120,
                  onDestinationSelected: (idx) {
                    setState(() => _tab = _SaxHubTab.values[idx]);
                  },
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FloatingActionButton.extended(
                      heroTag: 'desktop_new_routine',
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New Routine'),
                    ),
                  ),
                  destinations: _SaxHubTab.values
                      .map(
                        (s) => NavigationRailDestination(
                          icon: Icon(s.icon),
                          selectedIcon: Icon(s.selectedIcon),
                          label: Text(s.label),
                        ),
                      )
                      .toList(),
                ),
              Expanded(child: activeBody),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _tab.index,
                  onDestinationSelected: (idx) {
                    setState(() => _tab = _SaxHubTab.values[idx]);
                  },
                  destinations: _SaxHubTab.values
                      .map(
                        (s) => NavigationDestination(
                          icon: Icon(s.icon),
                          selectedIcon: Icon(s.selectedIcon),
                          label: s.label,
                        ),
                      )
                      .toList(),
                ),
          floatingActionButton: isDesktop || _tab != _SaxHubTab.studio
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'new_checklist_fab',
                      tooltip: 'New warmup checklist',
                      onPressed: () => _openEditor(isChecklist: true),
                      child: const Icon(Icons.check_box_outlined),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'new_routine_fab',
                      tooltip: 'New practice routine or chart',
                      onPressed: () => _openEditor(),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.item,
    required this.onTap,
    required this.onTogglePin,
    required this.onToggleArchive,
    required this.onTrashOrRestore,
    required this.onDeleteForever,
    required this.onToggleChecklistItem,
    this.compactList = false,
  });

  final SaxPracticeItem item;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleArchive;
  final VoidCallback onTrashOrRestore;
  final VoidCallback onDeleteForever;
  final ValueChanged<String> onToggleChecklistItem;
  final bool compactList;

  Widget _buildChecklistRow(
    PracticeChecklistItem step,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return InkWell(
      onTap: () => onToggleChecklistItem(step.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              step.isDone
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: step.isDone ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                step.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: step.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme, ColorScheme cs) {
    if (item.isLocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Locked studio entry — tap to unlock',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }
    if (item.isChecklist) {
      final rows = item.checklist
          .take(compactList ? 3 : 4)
          .map((step) => _buildChecklistRow(step, theme, cs))
          .toList();
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
      if (compactList) return column;
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: column,
      );
    }
    return Text(
      item.content.isEmpty ? 'No additional chart notes' : item.content,
      maxLines: compactList ? 3 : 5,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardColor = item.color == PracticeCardColor.neutral
        ? cs.surfaceContainerLow
        : item.color.surfaceFor(theme.brightness);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.color == PracticeCardColor.neutral
                  ? cs.outlineVariant.withValues(alpha: 0.45)
                  : item.color.accent.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: compactList ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? 'Untitled Sax Routine' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (item.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_rounded, size: 16, color: cs.primary),
                    ),
                  if (item.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin_rounded, size: 16, color: cs.primary),
                    ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onSelected: (action) {
                        switch (action) {
                          case 'pin':
                            onTogglePin();
                          case 'archive':
                            onToggleArchive();
                          case 'trash':
                            onTrashOrRestore();
                          case 'delete':
                            onDeleteForever();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(item.isPinned ? 'Unpin' : 'Pin'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(item.isArchived ? 'Unarchive' : 'Archive'),
                        ),
                        PopupMenuItem(
                          value: 'trash',
                          child: Text(
                            item.isTrashed ? 'Restore' : 'Move to Trash',
                          ),
                        ),
                        if (item.isTrashed)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Forever'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (compactList) ...[
                _buildBodyContent(theme, cs),
                const SizedBox(height: 10),
              ] else ...[
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildBodyContent(theme, cs),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${item.horn.transpositionKey} • ${item.targetBpm} BPM • ${item.durationMinutes}m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
