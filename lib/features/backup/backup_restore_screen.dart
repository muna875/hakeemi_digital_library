import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/utilities/date_formatter.dart';
import '../../services/backup/backup_service.dart';
import '../../shared/widgets/editorial_card.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  BackupSummary? _lastBackup;
  Map<String, dynamic>? _integrityReport;
  bool _busy = false;
  String? _statusMessage;

  Future<void> _exportBackup(AppState state) async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final summary = await state.createBackup();
      setState(() {
        _lastBackup = summary;
        _statusMessage =
            'Backup created: ${summary.bookCount} books, ${summary.chapterCount} chapters, ${summary.blockCount} blocks, ${summary.nuskhaCount} nuskhe, ${summary.imageCount} images.';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(AppState state) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Full Library?'),
        content: const Text(
          'Restoring will replace all four books, chapters, nuskhe, and settings with the selected backup archive. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final summary = await state.restoreBackup(path);
      setState(() {
        _statusMessage =
            'Restored ${summary.bookCount} books, ${summary.chapterCount} chapters, and ${summary.nuskhaCount} nuskhe.';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runIntegrityCheck(AppState state) async {
    final report = await state.database.runIntegrityCheck();
    setState(() => _integrityReport = report);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Archival Backup',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Exports all four books, chapters, sections, content blocks, Nuskha formulations, bookmarks, settings, and local images into a single offline ZIP archive. Your manuscripts never leave your device unless you explicitly share the file.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : () => _exportBackup(state),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Create Backup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _restoreBackup(state),
                        icon: const Icon(Icons.restore_outlined),
                        label: const Text('Restore ZIP'),
                      ),
                    ),
                  ],
                ),
                if (_lastBackup != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Latest Backup (${DateFormatter.formatDateTime(_lastBackup!.createdAt)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastBackup!.filePath,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Share.shareXFiles(
                      [XFile(_lastBackup!.filePath)],
                      text: 'Hakeemi Digital Library Backup',
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share Backup Archive'),
                  ),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sageTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryForestGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database Integrity Check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Verify SQLite database health and confirm all four permanent book slots are intact.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _runIntegrityCheck(state),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Run Integrity Check'),
                ),
                if (_integrityReport != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Status: ${_integrityReport!['isHealthy'] == true ? 'Healthy (OK)' : 'Attention Needed'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _integrityReport!['isHealthy'] == true
                          ? AppColors.successGreen
                          : AppColors.dangerRed,
                    ),
                  ),
                  Text(
                    'Books: ${_integrityReport!['bookCount']} • Chapters: ${_integrityReport!['chapterCount']} • Blocks: ${_integrityReport!['blockCount']} • Nuskhe: ${_integrityReport!['nuskhaCount']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
