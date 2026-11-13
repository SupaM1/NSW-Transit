import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings_store.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onKeySaved;
  const OnboardingScreen({super.key, required this.onKeySaved});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = TextEditingController();
  final _store = SettingsStore();
  bool _saving = false;
  String? _error;

  Future<void> _openRegistrationPage() async {
    final uri = Uri.parse('https://opendata.transport.nsw.gov.au/data/user/register');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Paste your API key first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await _store.setApiKey(key);
    if (!mounted) return;
    widget.onKeySaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.directions_bus, size: 56, color: Color(0xFF00A6E4)),
              const SizedBox(height: 16),
              Text('NSW Transit', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Free. Open-source. No ads, no accounts, no tracking.\n'
                'This app talks directly to Transport for NSW\'s official '
                'Open Data API from your device — there is no server in '
                'between collecting your data.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('One-time setup', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Transport for NSW requires every app to use its own '
                        'free API key. Register for one (takes about a '
                        'minute, no payment details needed), then paste it '
                        'below. Your key is stored only on this device.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openRegistrationPage,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Get a free API key'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Your TfNSW API key',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                obscureText: true,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
