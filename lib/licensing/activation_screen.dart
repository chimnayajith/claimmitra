import 'package:flutter/material.dart';

import 'license_service.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key, required this.onActivated});
  final VoidCallback onActivated;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LicenseService.instance.activate(_keyController.text);
      if (mounted) widget.onActivated();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = LicenseService.instance.isConfigured;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/branding/claimmitra_icon.png', height: 64),
                    const SizedBox(height: 20),
                    Text('Activate ClaimMitra', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Enter the licence key supplied with your purchase. Activation requires an internet connection. After activation, ClaimMitra can be used offline on this computer.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keyController,
                      enabled: !_busy && configured,
                      decoration: const InputDecoration(labelText: 'Licence key', hintText: 'Paste your licence key'),
                      onSubmitted: (_) => _activate(),
                    ),
                    if (!configured) ...[
                      const SizedBox(height: 12),
                      const Text('This build is missing Supabase licensing configuration. Configure the build-time values before distributing it.', style: TextStyle(color: Colors.red)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy || !configured ? null : _activate,
                      child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Activate'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.child});
  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late Future<bool> _validLicense;
  bool _justActivated = false;

  @override
  void initState() {
    super.initState();
    _validLicense = LicenseService.instance.hasValidLocalLicense();
  }

  void _activated() => setState(() => _justActivated = true);

  @override
  Widget build(BuildContext context) {
    if (_justActivated) return widget.child;
    return FutureBuilder<bool>(
      future: _validLicense,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text('Checking ClaimMitra licence…')]))),
          );
        }
        if (snapshot.data == true) return widget.child;
        return MaterialApp(
          title: 'ClaimMitra Activation',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), fontFamily: 'Inter'),
          home: ActivationScreen(onActivated: _activated),
        );
      },
    );
  }
}
