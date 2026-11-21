import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../shared/widgets/editorial_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _authorCtrl = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _authorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    if (!_loaded) {
      _authorCtrl.text = settings.defaultAuthorName;
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading & Pagination Typography',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Book Font Size'),
                    Text(
                      '${settings.defaultFontSize.round()} pt',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryForestGreen,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.defaultFontSize.clamp(10.0, 20.0),
                  min: 10.0,
                  max: 20.0,
                  divisions: 10,
                  activeColor: AppColors.primaryForestGreen,
                  onChanged: (v) => state.updateSettings(
                    settings.copyWith(defaultFontSize: v),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: settings.defaultDirection,
                  decoration: const InputDecoration(
                    labelText: 'Default Text Direction',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Auto-Detect (Urdu RTL / English LTR)'),
                    ),
                    DropdownMenuItem(
                      value: 'rtl',
                      child: Text('Right-to-Left (Urdu Default)'),
                    ),
                    DropdownMenuItem(
                      value: 'ltr',
                      child: Text('Left-to-Right (English Default)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      state.updateSettings(
                        settings.copyWith(defaultDirection: v),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Layout & PDF Defaults',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Running Headers'),
                  value: settings.showRunningHeaders,
                  onChanged: (v) => state.updateSettings(
                    settings.copyWith(showRunningHeaders: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Page Numbers'),
                  value: settings.showPageNumbers,
                  onChanged: (v) => state.updateSettings(
                    settings.copyWith(showPageNumbers: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Author Page in PDF'),
                  value: settings.includeAuthorPageInPdf,
                  onChanged: (v) => state.updateSettings(
                    settings.copyWith(includeAuthorPageInPdf: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Back Cover in PDF'),
                  value: settings.includeBackCoverInPdf,
                  onChanged: (v) => state.updateSettings(
                    settings.copyWith(includeBackCoverInPdf: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practitioner Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _authorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Default Hakeem / Author Name',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await state.updateSettings(
                      settings.copyWith(
                        defaultAuthorName: _authorCtrl.text.trim(),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved.')),
                      );
                    }
                  },
                  child: const Text('Save Practitioner Name'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorialCard(
            color: AppColors.sageTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline & AI Architecture Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'All 4 books, pagination, Urdu/English search, and PDF publishing run 100% locally on your device. Optional AI assistance is disabled (${state.aiService.isEnabled ? 'Enabled' : 'Disabled'}).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
