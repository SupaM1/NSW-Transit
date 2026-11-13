import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SettingsStore();
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _store.getApiKey().then((key) {
      _controller.text = key ?? '';
      setState(() => _loaded = true);
    });
  }

  Future<void> _save() async {
    await _store.setApiKey(_controller.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key saved')));
  }

  Future<void> _clear() async {
    await _store.clearApiKey();
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key removed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transport for NSW API key', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(onPressed: _save, child: const Text('Save')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _clear, child: const Text('Remove')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'NSW Transit is free, open-source, and collects no data. '
                    'There are no ads, no accounts, no analytics, and no '
                    'backend server — your API key and GPS location stay on '
                    'this device, and every request goes straight to '
                    'Transport for NSW\'s own Open Data API.',
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://opendata.transport.nsw.gov.au/data/user/register'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Get / manage your API key'),
                  ),
                ],
              ),
            ),
    );
  }
}
