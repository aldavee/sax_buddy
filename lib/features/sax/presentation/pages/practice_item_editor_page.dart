import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sax_buddy/core/presentation/widgets/app_snackbar.dart';
import 'package:sax_buddy/features/sax/data/sax_repository.dart';
import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';
import 'package:sax_buddy/features/security/data/biometric_service.dart';

class PracticeItemEditorPage extends StatefulWidget {
  const PracticeItemEditorPage({
    this.initialItem,
    this.initialChecklist = false,
    this.defaultFolder = 'Daily Routine',
    super.key,
  });

  final SaxPracticeItem? initialItem;
  final bool initialChecklist;
  final String defaultFolder;

  @override
  State<PracticeItemEditorPage> createState() => _PracticeItemEditorPageState();
}

class _PracticeItemEditorPageState extends State<PracticeItemEditorPage> {
  final SaxRepository _repo = SaxRepository.instance;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagInputCtrl;
  late final TextEditingController _checkInputCtrl;

  late String _folder;
  late SaxHornType _horn;
  late String _keySignature;
  late int _targetBpm;
  late int _durationMinutes;
  late bool _isChecklist;
  late bool _isPinned;
  late bool _isFavorite;
  late bool _isLocked;
  late PracticeCardColor _color;
  late List<String> _tags;
  late List<PracticeChecklistItem> _checklist;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _contentCtrl = TextEditingController(text: item?.content ?? '');
    _tagInputCtrl = TextEditingController();
    _checkInputCtrl = TextEditingController();

    _folder = item?.folder ?? widget.defaultFolder;
    _horn = item?.horn ?? _repo.selectedHorn;
    _keySignature = item?.keySignature ?? 'C';
    _targetBpm = item?.targetBpm ?? 120;
    _durationMinutes = item?.durationMinutes ?? 20;
    _isChecklist = item?.isChecklist ?? widget.initialChecklist;
    _isPinned = item?.isPinned ?? false;
    _isFavorite = item?.isFavorite ?? false;
    _isLocked = item?.isLocked ?? false;
    _color = item?.color ?? PracticeCardColor.neutral;
    _tags = List<String>.from(item?.tags ?? const []);
    _checklist = List<PracticeChecklistItem>.from(item?.checklist ?? const []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagInputCtrl.dispose();
    _checkInputCtrl.dispose();
    super.dispose();
  }

  void _addChecklistStep() {
    final text = _checkInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(
        PracticeChecklistItem(
          id: 'step-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
        ),
      );
      _checkInputCtrl.clear();
    });
  }

  void _addTag() {
    final clean = _tagInputCtrl.text.trim().replaceAll('#', '').toLowerCase();
    if (clean.isEmpty || _tags.contains(clean)) {
      _tagInputCtrl.clear();
      return;
    }
    setState(() {
      _tags.add(clean);
      _tagInputCtrl.clear();
    });
  }

  Future<void> _saveAndClose() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty && _checklist.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now().toUtc();
    final existing = widget.initialItem;
    final item = SaxPracticeItem(
      id: existing?.id ?? 'sax-${now.microsecondsSinceEpoch}',
      title: title.isEmpty ? 'Untitled Sax Routine' : title,
      content: content,
      folder: _folder,
      horn: _horn,
      keySignature: _keySignature,
      targetBpm: _targetBpm,
      durationMinutes: _durationMinutes,
      tags: _tags,
      checklist: _checklist,
      isChecklist: _isChecklist,
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      isArchived: existing?.isArchived ?? false,
      isTrashed: existing?.isTrashed ?? false,
      isLocked: _isLocked,
      color: _color,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _repo.upsertItem(item);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bgColor = _color == PracticeCardColor.neutral
        ? theme.scaffoldBackgroundColor
        : _color.surfaceFor(theme.brightness);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveAndClose,
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            widget.initialItem == null
                ? 'New Sax Routine / Chart'
                : 'Edit Sax Routine / Chart',
          ),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Unpin' : 'Pin to top',
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _isPinned ? cs.primary : null,
              ),
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
            IconButton(
              tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
              icon: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite ? Colors.amber : null,
              ),
              onPressed: () => setState(() => _isFavorite = !_isFavorite),
            ),
            IconButton(
              tooltip: _isChecklist ? 'Switch to text mode' : 'Enable checklist',
              icon: Icon(
                _isChecklist
                    ? Icons.check_box_rounded
                    : Icons.check_box_outlined,
                color: _isChecklist ? cs.primary : null,
              ),
              onPressed: () => setState(() => _isChecklist = !_isChecklist),
            ),
            IconButton(
              tooltip: _isLocked ? 'Unlock item' : 'Lock with biometrics',
              icon: Icon(
                _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _isLocked ? cs.primary : null,
              ),
              onPressed: () async {
                if (!_isLocked && BiometricService.instance.isSupported) {
                  final res = await BiometricService.instance.authenticate(
                    reason: 'Confirm identity to lock practice entry',
                  );
                  if (!res.success) {
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        res.errorMessage ?? 'Authentication failed',
                        backgroundColor: cs.error,
                      );
                    }
                    return;
                  }
                }
                setState(() => _isLocked = !_isLocked);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: FilledButton.icon(
                onPressed: _saveAndClose,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _repo.folders.contains(_folder)
                              ? _folder
                              : _repo.folders.first,
                          items: _repo.folders
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _folder = v);
                          },
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<SaxHornType>(
                          value: _horn,
                          items: SaxHornType.values
                              .map(
                                (h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(h.shortBadge),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _horn = v);
                          },
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: HornTransposer.circleKeys.contains(_keySignature)
                              ? _keySignature
                              : 'C',
                          items: HornTransposer.circleKeys
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text('Key: $k'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _keySignature = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Tempo: $_targetBpm BPM',
                            style: theme.textTheme.labelMedium,
                          ),
                          Slider(
                            value: _targetBpm.clamp(40, 240).toDouble(),
                            min: 40,
                            max: 240,
                            divisions: 200,
                            onChanged: (v) =>
                                setState(() => _targetBpm = v.round()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Duration: $_durationMinutes min',
                            style: theme.textTheme.labelMedium,
                          ),
                          Slider(
                            value: _durationMinutes.clamp(5, 120).toDouble(),
                            min: 5,
                            max: 120,
                            divisions: 23,
                            onChanged: (v) =>
                                setState(() => _durationMinutes = v.round()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PracticeCardColor.values.map((c) {
                    final selected = _color == c;
                    return ChoiceChip(
                      label: Text(c.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _color = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleCtrl,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Routine, Tune Title, or Setup Name...',
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                if (_isChecklist) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checkInputCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Add practice step (e.g., Overtones on Low Bb 5 min)...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addChecklistStep(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _addChecklistStep,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Step'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._checklist.map(
                    (step) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: step.isDone,
                      title: Text(
                        step.text,
                        style: TextStyle(
                          decoration:
                              step.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(
                          () => _checklist.removeWhere((c) => c.id == step.id),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          final idx =
                              _checklist.indexWhere((c) => c.id == step.id);
                          if (idx >= 0) {
                            _checklist[idx] =
                                step.copyWith(isDone: val ?? false);
                          }
                        });
                      },
                    ),
                  ),
                  const Divider(height: 24),
                ],
                TextField(
                  controller: _contentCtrl,
                  minLines: 7,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText:
                        'Write chord changes (| Cm7 | F7 | BbMaj7 |), voicing notes, transcription licks, or reed rotation notes...',
                    border: InputBorder.none,
                  ),
                ),
                const Divider(height: 28),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._tags.map(
                      (t) => InputChip(
                        label: Text('#$t'),
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: TextField(
                        controller: _tagInputCtrl,
                        decoration: const InputDecoration(
                          hintText: '+ Add #tag',
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
