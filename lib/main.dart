import 'package:material_ui/material_ui.dart';

import 'core/settings_store.dart';
import 'screens/nearby_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const NswTransitApp());
}

class NswTransitApp extends StatelessWidget {
  const NswTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSW Transit',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A6E4)), useMaterial3: true),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A6E4), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const _RootDecider(),
    );
  }
}

class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  final _settings = SettingsStore();
  bool _loading = true;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final key = await _settings.getApiKey();
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasKey) {
      return OnboardingScreen(onKeySaved: () => setState(() => _hasKey = true));
    }
    return const NearbyScreen();
  }
}
