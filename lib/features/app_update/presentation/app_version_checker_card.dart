import 'package:material_ui/material_ui.dart';
import 'package:sax_buddy/features/app_update/data/app_update_service.dart';

class AppVersionCheckerCard extends StatefulWidget {
  const AppVersionCheckerCard({
    this.updateService,
    this.autoCheckOnInit = true,
    super.key,
  });

  final AppUpdateService? updateService;
  final bool autoCheckOnInit;

  @override
  State<AppVersionCheckerCard> createState() => _AppVersionCheckerCardState();
}

class _AppVersionCheckerCardState extends State<AppVersionCheckerCard> {
  late AppUpdateService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService.instance;
    _service.addListener(_onChanged);
    _service.initialize().then((_) {
      if (mounted &&
          widget.autoCheckOnInit &&
          _service.status == AppUpdateStatus.idle) {
        _service.checkForUpdate(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _service.status;
    final release = _service.latestRelease;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Updates',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Current version: ${_service.displayCurrentVersion}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: status == AppUpdateStatus.checking ||
                          status == AppUpdateStatus.downloading
                      ? null
                      : () => _service.checkForUpdate(),
                  child: Text(
                    status == AppUpdateStatus.checking ? 'Checking...' : 'Check',
                  ),
                ),
              ],
            ),
            if (status == AppUpdateStatus.updateAvailable && release != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New version available: ${release.tagName} (${release.formattedSize})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    if (release.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        release.notes,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _service.downloadAndInstallUpdate,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Update'),
                    ),
                  ],
                ),
              ),
            ] else if (status == AppUpdateStatus.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _service.downloadProgress),
              const SizedBox(height: 6),
              Text(
                'Downloading ${(100 * _service.downloadProgress).toStringAsFixed(0)}%...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (status == AppUpdateStatus.upToDate) ...[
              const SizedBox(height: 8),
              Text(
                'You are running the latest version.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                    ),
              ),
            ] else if (status == AppUpdateStatus.error &&
                _service.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _service.errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
