import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _serverController = TextEditingController(text: 'http://');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  // null = unknown, true = needs first-run setup, false = normal login
  bool? _needsSetup;
  bool _serverChecked = false;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    final serverUrl = _serverController.text.trim();
    if (serverUrl.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ApiClient(baseUrl: serverUrl);
      final status = await client.authStatus();
      final needsSetup = status['needs_setup'] as bool;

      setState(() {
        _needsSetup = needsSetup;
        _serverChecked = true;
      });
    } catch (e) {
      setState(() => _error = 'Could not reach server: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ApiClient(baseUrl: _serverController.text.trim());
      final String token;

      if (_needsSetup == true) {
        token = await client.register(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      } else {
        token = await client.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }

      await ref.read(authProvider.notifier).login(
            serverUrl: _serverController.text.trim(),
            token: token,
          );
    } catch (e) {
      setState(() => _error = _needsSetup == true
          ? 'Setup failed: $e'
          : 'Login failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSetupGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Setup your Cloudbox server',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text(
                'Cloudbox is self-hosted — you run the server on your own computer or VPS. '
                'Your photos and files stay on your hardware.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _guideStep(context, '1', 'Install Docker',
                  'Download and install Docker Desktop for your operating system.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => launchUrl(
                  Uri.parse('https://docs.docker.com/get-docker/'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Get Docker'),
              ),
              const SizedBox(height: 20),
              _guideStep(context, '2', 'Download Cloudbox',
                  'Open a terminal and run:'),
              const SizedBox(height: 8),
              _codeBlock(context,
                  'git clone https://github.com/Slush97/cloudbox.git\n'
                  'cd cloudbox'),
              const SizedBox(height: 20),
              _guideStep(context, '3', 'Start the server',
                  'Run this single command:'),
              const SizedBox(height: 8),
              _codeBlock(context,
                  'docker compose -f docker-compose.prod.yml up -d'),
              const SizedBox(height: 20),
              _guideStep(context, '4', 'Connect',
                  'Enter your server address above (usually http://localhost:3000) '
                  'and create your account.'),
              const SizedBox(height: 20),
              _guideStep(context, '5', 'Access from anywhere (optional)',
                  'Install Tailscale on your server and phone for secure '
                  'access from any network.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => launchUrl(
                  Uri.parse('https://tailscale.com/download'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Get Tailscale'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideStep(
      BuildContext context, String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(number,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeBlock(BuildContext context, String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.cloud,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cloudbox',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _serverChecked ? _submit() : _checkServer(),
                  enabled: !_serverChecked,
                ),
                if (!_serverChecked) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _checkServer,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Connect'),
                  ),
                ],
                if (_serverChecked) ...[
                  const SizedBox(height: 16),
                  if (_needsSetup == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Welcome! Create your account to get started.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_needsSetup == true ? 'Create Account' : 'Sign In'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _serverChecked = false;
                      _needsSetup = null;
                      _error = null;
                    }),
                    child: const Text('Change server'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => _showSetupGuide(context),
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Need a server? Setup guide'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
