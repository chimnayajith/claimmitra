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
  bool _downloading = false;
  double? _progress;

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
              if (_downloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _progress == null
                      ? 'Downloading the update...'
                      : 'Downloading ${(100 * _progress!).round()}%',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _downloading ? null : () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: _downloading
                ? null
                : () async {
                    setState(() {
                      _downloading = true;
                      _progress = null;
                    });
                    try {
                      await UpdateService.instance.downloadAndInstall(
                        update,
                        onProgress: (progress) {
                          if (mounted) setState(() => _progress = progress);
                        },
                      );
                    } catch (error) {
                      if (mounted) {
                        setState(() => _downloading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $error')),
                        );
                      }
                    }
                  },
            child: Text(_downloading ? 'Downloading...' : 'Update now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
