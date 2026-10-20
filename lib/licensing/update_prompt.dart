import 'package:flutter/material.dart';

import 'update_service.dart';

class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({super.key, required this.child});
  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final update = await UpdateService.instance.checkForUpdate();
    if (!mounted || update == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ClaimMitra ${update.version} is available'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A newer version is available. Your cases, licence, and backups are stored separately from the application.'),
              if (update.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Release notes', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(update.notes),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await UpdateService.instance.openDownload(update.downloadUrl);
              } catch (error) {
                debugPrint('Could not open ClaimMitra download: $error');
              }
            },
            child: const Text('Download update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
