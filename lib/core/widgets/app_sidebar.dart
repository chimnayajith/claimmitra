import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../database/backup_service.dart';
import '../../licensing/update_service.dart';
import 'sidebar_item.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _currentVersion =
      UpdateService.currentVersion;

  DateTime? _lastBackup;
  bool _loadingBackup = true;
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    try {
      final backups = await BackupService.instance.listBackups();

      DateTime? latest;
      if (backups.isNotEmpty) {
        latest = await backups.first.lastModified();
      }

      if (!mounted) return;
      setState(() {
        _lastBackup = latest;
        _loadingBackup = false;
      });
    } catch (error) {
      debugPrint('Could not load latest backup: $error');
      if (!mounted) return;
      setState(() => _loadingBackup = false);
    }
  }

  String _formatBackupTime(DateTime? time) {
    if (time == null) return 'No backups found';

    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;

    final date = sameDay
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : '${local.day.toString().padLeft(2, '0')}/'
              '${local.month.toString().padLeft(2, '0')}/'
              '${local.year}';

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$date, $hour:$minute $period';
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;

    setState(() => _checkingUpdates = true);

    try {
      final update = await UpdateService.instance.checkForUpdate();

      if (!mounted) return;

      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are up to date, or the update check could not connect.',
            ),
          ),
        );
        return;
      }

      final openUpdate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'ClaimMitra ${update.version} is available.\n\n'
            'Your version: $_currentVersion\n'
            'Available version: ${update.version}'
            '${update.notes.isNotEmpty ? '\n\n${update.notes}' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download update'),
            ),
          ],
        ),
      );

      if (openUpdate == true && mounted) {
        await UpdateService.instance.openDownload(update.downloadUrl);
      }
    } catch (error) {
      debugPrint('Update check failed: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates. Try again later.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingUpdates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final isDashboard = location == '/';
    final isCases = location.startsWith('/cases');

    return Container(
      width: 240,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Image.asset(
              'assets/branding/claimmitra_icon.png',
              width: 48,
              height: 48,
            ),

            const SizedBox(height: 10),

            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                children: const [
                  TextSpan(
                    text: 'Claim',
                    style: TextStyle(color: Color(0xFF0F2A56)),
                  ),
                  TextSpan(
                    text: 'Mitra',
                    style: TextStyle(color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SidebarItem(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              selected: isDashboard,
              onTap: () => context.go('/'),
            ),

            SidebarItem(
              icon: Icons.folder_outlined,
              title: 'Cases',
              selected: isCases,
              onTap: () => context.go('/cases'),
            ),

            const Spacer(),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.backup_outlined,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Last backup',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 25),
                    child: Text(
                      _loadingBackup
                          ? 'Loading…'
                          : _formatBackupTime(_lastBackup),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Version $_currentVersion',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _checkingUpdates ? null : _checkForUpdates,
                      icon: _checkingUpdates
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.system_update_alt,
                              size: 17,
                            ),
                      label: Text(
                        _checkingUpdates
                            ? 'Checking…'
                            : 'Check for updates',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
