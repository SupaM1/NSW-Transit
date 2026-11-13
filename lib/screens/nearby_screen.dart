import 'package:material_ui/material_ui.dart';

import '../core/location_service.dart';
import '../core/models.dart';
import '../core/settings_store.dart';
import '../core/tfnsw_client.dart';
import '../core/transport_mode.dart';
import '../widgets/mode_badge.dart';
import 'settings_screen.dart';

/// Runs [tasks] with at most [concurrency] running at once, instead of all
/// at the same time — Transport for NSW's free API key enforces a rate
/// limit that firing every nearby-stop request simultaneously can exceed.
Future<List<T>> _withLimitedConcurrency<T>(
    List<Future<T> Function()> tasks, {
      required int concurrency,
    }) async {
  final results = List<T?>.filled(tasks.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      if (index >= tasks.length) return;
      nextIndex++;
      results[index] = await tasks[index]();
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
  return results.cast<T>();
}

class _StopResult {
  final NearbyStop stop;
  final List<Departure> departures;
  final String? error;
  _StopResult({required this.stop, required this.departures, this.error});
}

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _location = LocationService();
  final _settings = SettingsStore();

  bool _loading = true;
  String? _error;
  bool _needsApiKey = false;
  List<_StopResult> _results = [];
  bool _schoolBusOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsApiKey = false;
    });

    try {
      final apiKey = await _settings.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        setState(() {
          _loading = false;
          _needsApiKey = true;
        });
        return;
      }

      final position = await _location.getCurrentPosition();
      final client = TfNswClient(apiKey: apiKey);

      final stops = await client.nearbyStops(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMetres: 1200,
      );

      final nearest = stops.take(10).toList();
      final results = await _withLimitedConcurrency<_StopResult>(
        nearest.map((stop) => () async {
          try {
            final departures = await client.departures(stopId: stop.id);
            return _StopResult(stop: stop, departures: departures);
          } catch (e) {
            return _StopResult(stop: stop, departures: const [], error: e.toString());
          }
        }).toList(),
        concurrency: 3,
      );

      if (!mounted) return;
      setState(() {
        _results = results.where((r) => r.departures.isNotEmpty || r.error != null).toList();
        _loading = false;
      });
    } on LocationUnavailableException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on TfNswApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
        _needsApiKey = e.message.contains('API key');
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  void _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby departures'),
        actions: [
          IconButton(
            tooltip: _schoolBusOnly ? 'Show all modes' : 'School buses only',
            icon: Icon(Icons.school, color: _schoolBusOnly ? Theme.of(context).colorScheme.primary : null),
            onPressed: () => setState(() => _schoolBusOnly = !_schoolBusOnly),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_needsApiKey) {
      return _CenteredMessage(
        icon: Icons.vpn_key_off,
        message: 'Add your free Transport for NSW API key to see live departures.',
        actionLabel: 'Open settings',
        onAction: _openSettings,
      );
    }

    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    final visibleResults = _schoolBusOnly
        ? _results
        .map((r) => _StopResult(
      stop: r.stop,
      departures: r.departures.where((d) => d.mode == TransportMode.schoolBus).toList(),
      error: r.error,
    ))
        .where((r) => r.departures.isNotEmpty)
        .toList()
        : _results;

    if (visibleResults.isEmpty) {
      return _CenteredMessage(
        icon: _schoolBusOnly ? Icons.school : Icons.location_searching,
        message: _schoolBusOnly
            ? 'No school bus services found at nearby stops right now.'
            : 'No upcoming departures found at stops near you.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: visibleResults.length,
        itemBuilder: (context, index) => _StopCard(result: visibleResults[index]),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final _StopResult result;
  const _StopCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final stop = result.stop;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stop.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (stop.distanceMetres != null)
                  Text('${stop.distanceMetres!.round()} m', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (result.error != null)
              Text(result.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else
              ...result.departures.map((d) => _DepartureRow(departure: d)),
          ],
        ),
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  final Departure departure;
  const _DepartureRow({required this.departure});

  String _countdown() {
    final diff = departure.bestTime.difference(DateTime.now());
    if (departure.isCancelled) return 'Cancelled';
    if (diff.inMinutes <= 0) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    final hours = diff.inMinutes ~/ 60;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = departure.isCancelled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ModeBadge(mode: departure.mode),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${departure.routeName} ${departure.destination}'.trim(),
              style: TextStyle(
                decoration: cancelled ? TextDecoration.lineThrough : null,
                color: cancelled ? Theme.of(context).colorScheme.outline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (departure.isRealtime && !cancelled)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.wifi_tethering, size: 14, color: Colors.green),
            ),
          Text(
            _countdown(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cancelled ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
