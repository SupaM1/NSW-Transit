import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
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

class _NearbyScreenState extends State<NearbyScreen> with WidgetsBindingObserver {
  static const _tickInterval = Duration(seconds: 20);
  static const _refreshInterval = Duration(seconds: 30);

  final _location = LocationService();
  final _settings = SettingsStore();

  bool _loading = true;
  String? _error;
  bool _needsApiKey = false;
  List<_StopResult> _results = [];
  bool _includeSchoolBuses = false;
  DateTime? _lastUpdated;
  DateTime? _selectedAt;

  TfNswClient? _client;
  List<NearbyStop> _stops = [];
  Timer? _tickTimer;
  Timer? _refreshTimer;

  // Explicit, stop-ID-keyed expand/collapse state. Kept here (rather than
  // relying on each ExpansionTile's own internal state) so a stop's
  // collapsed state survives even if it briefly drops out of the results
  // list (e.g. a momentary empty response) and reappears later.
  final Set<String> _collapsedStopIds = {};
  final Map<String, ExpansibleController> _tileControllers = {};

  final _schoolBusIconKey = GlobalKey();
  OverlayEntry? _schoolBusTipEntry;

  // Stops the user has starred, persisted on-device. A starred stop shows
  // up both in the Starred section at the top of the list and in its usual
  // distance-sorted spot further down.
  Set<String> _starredStopIds = {};
  bool _starredSectionExpanded = true;
  final _starredSectionKey = GlobalKey();
  OverlayEntry? _starredTipEntry;

  ExpansibleController _controllerFor(String stopId) {
    return _tileControllers.putIfAbsent(stopId, () => ExpansibleController());
  }

  void _expandAll() {
    setState(() => _collapsedStopIds.clear());
    for (final controller in _tileControllers.values) {
      if (!controller.isExpanded) controller.expand();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.getIncludeSchoolBuses().then((value) {
      if (mounted) setState(() => _includeSchoolBuses = value);
    });
    _settings.getStarredStopIds().then((ids) {
      if (mounted) setState(() => _starredStopIds = ids);
    });
    _maybeShowSchoolBusTip();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _refreshTimer?.cancel();
    _schoolBusTipEntry?.remove();
    _starredTipEntry?.remove();
    super.dispose();
  }

  void _toggleStarred(String stopId) {
    final wasEmpty = _starredStopIds.isEmpty;
    setState(() {
      if (_starredStopIds.contains(stopId)) {
        _starredStopIds.remove(stopId);
      } else {
        _starredStopIds.add(stopId);
      }
    });
    _settings.setStarredStopIds(_starredStopIds);
    if (wasEmpty && _starredStopIds.isNotEmpty) {
      _maybeShowStarredTip();
    }
  }

  /// Shows a one-time explainer bubble pointing at the new Starred section,
  /// right after the user stars their very first stop. Never shown again
  /// once dismissed.
  void _maybeShowStarredTip() async {
    final hasSeen = await _settings.getHasSeenStarredTip();
    if (hasSeen || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _starredSectionKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final sectionPosition = renderBox.localToGlobal(Offset.zero);
      final sectionSize = renderBox.size;
      final screenWidth = MediaQuery.of(context).size.width;

      const bubbleWidth = 260.0;
      final arrowCenterX = sectionPosition.dx + sectionSize.width / 2;
      final bubbleLeft = (arrowCenterX - bubbleWidth / 2).clamp(12.0, screenWidth - bubbleWidth - 12.0);
      final arrowLeftOffset = (arrowCenterX - bubbleLeft - 8).clamp(12.0, bubbleWidth - 28.0);

      void dismiss() {
        _starredTipEntry?.remove();
        _starredTipEntry = null;
        _settings.setHasSeenStarredTip(true);
      }

      final entry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: dismiss),
            ),
            Positioned(
              top: sectionPosition.dy + sectionSize.height + 4,
              left: bubbleLeft,
              width: bubbleWidth,
              child: _SpeechBubble(
                message: 'Your starred stops will appear here.',
                arrowLeftOffset: arrowLeftOffset,
                onDismiss: dismiss,
              ),
            ),
          ],
        ),
      );
      _starredTipEntry = entry;
      Overlay.of(context).insert(entry);
    });
  }

  /// Shows a one-time explainer bubble pointing at the school bus button,
  /// the first time the screen opens after this feature was added. Never
  /// shown again once dismissed.
  void _maybeShowSchoolBusTip() async {
    final hasSeen = await _settings.getHasSeenSchoolBusTip();
    if (hasSeen || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _schoolBusIconKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final iconPosition = renderBox.localToGlobal(Offset.zero);
      final iconSize = renderBox.size;
      final screenWidth = MediaQuery.of(context).size.width;

      const bubbleWidth = 260.0;
      final arrowCenterX = iconPosition.dx + iconSize.width / 2;
      final bubbleLeft = (arrowCenterX - bubbleWidth / 2).clamp(12.0, screenWidth - bubbleWidth - 12.0);
      final arrowLeftOffset = (arrowCenterX - bubbleLeft - 8).clamp(12.0, bubbleWidth - 28.0);

      void dismiss() {
        _schoolBusTipEntry?.remove();
        _schoolBusTipEntry = null;
        _settings.setHasSeenSchoolBusTip(true);
      }

      final entry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: dismiss),
            ),
            Positioned(
              top: iconPosition.dy + iconSize.height + 4,
              left: bubbleLeft,
              width: bubbleWidth,
              child: _SpeechBubble(
                message:
                "This button shows school buses in your timetable. Don't worry, we'll remember whether you catch school buses.",
                arrowLeftOffset: arrowLeftOffset,
                onDismiss: dismiss,
              ),
            ),
          ],
        ),
      );
      _schoolBusTipEntry = entry;
      Overlay.of(context).insert(entry);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLiveUpdates();
      _refreshDepartures();
    } else {
      _stopLiveUpdates();
    }
  }

  void _startLiveUpdates() {
    _stopLiveUpdates();
    // Ticks the UI so each departure's countdown keeps counting down even
    // between network refreshes.
    _tickTimer = Timer.periodic(_tickInterval, (_) {
      if (mounted) setState(() {});
    });
    // Quietly re-fetches real departure data (picking up real-time delays)
    // without showing a loading spinner or losing scroll position.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshDepartures());
  }

  void _stopLiveUpdates() {
    _tickTimer?.cancel();
    _refreshTimer?.cancel();
    _tickTimer = null;
    _refreshTimer = null;
  }

  Future<void> _load() async {
    _stopLiveUpdates();
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
      final results = await _fetchDepartures(client, nearest);

      if (!mounted) return;
      _client = client;
      _stops = nearest;
      setState(() {
        _results = results;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
      _startLiveUpdates();
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

  Future<List<_StopResult>> _fetchDepartures(TfNswClient client, List<NearbyStop> stops) async {
    final results = await _withLimitedConcurrency<_StopResult>(
      stops.map((stop) => () async {
        try {
          final departures = await client.departures(stopId: stop.id, at: _selectedAt);
          return _StopResult(stop: stop, departures: departures);
        } catch (e) {
          return _StopResult(stop: stop, departures: const [], error: e.toString());
        }
      }).toList(),
      concurrency: 3,
    );
    return results.where((r) => r.departures.isNotEmpty || r.error != null).toList();
  }

  /// Re-fetches departures for the stops already found, without re-running
  /// location lookup or showing a loading state. Failures are ignored so a
  /// momentary network hiccup doesn't disrupt what's already on screen.
  Future<void> _refreshDepartures() async {
    final client = _client;
    if (client == null || _stops.isEmpty) return;
    try {
      final results = await _fetchDepartures(client, _stops);
      if (!mounted) return;
      setState(() {
        _results = results;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      // Keep showing the last good data; the next tick will try again.
    }
  }

  String? _lastUpdatedLabel() {
    final updated = _lastUpdated;
    if (updated == null) return null;
    final diff = DateTime.now().difference(updated);
    if (diff.inSeconds < 10) return 'Updated just now';
    if (diff.inMinutes < 1) return 'Updated ${diff.inSeconds}s ago';
    return 'Updated ${diff.inMinutes}m ago';
  }

  void _openSettings() async {
    _stopLiveUpdates();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    _load();
  }

  /// Lets the user look up departures at a future date/time instead of
  /// right now. Transport for NSW's timetable data only looks a couple of
  /// weeks ahead, so that's the window offered here.
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = (_selectedAt ?? now).isBefore(now) ? now : (_selectedAt ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;

    setState(() => _selectedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    _applySelectedTimeChange();
  }

  void _clearSelectedTime() {
    setState(() => _selectedAt = null);
    _applySelectedTimeChange();
  }

  String _formatSelectedAt(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'am' : 'pm';
    final time = '$hour12:$minute$period';
    if (isToday) return 'Today, $time';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]} ${dt.day}, $time';
  }

  /// Re-fetches departures for the stops already found, using whatever
  /// [_selectedAt] now holds (or live/now if it's been cleared).
  Future<void> _applySelectedTimeChange() async {
    final client = _client;
    if (client == null || _stops.isEmpty) return;

    setState(() => _loading = true);
    try {
      final results = await _fetchDepartures(client, _stops);
      if (!mounted) return;
      setState(() {
        _results = results;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
    } on TfNswApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nearby departures'),
            if (_lastUpdatedLabel() != null)
              Text(
                _lastUpdatedLabel()!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Expand all',
            icon: const Icon(Icons.unfold_more),
            onPressed: _expandAll,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_stops.isNotEmpty) _buildFilterBar(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: [
            _buildTimeFilterChip(context),
            _buildSchoolBusFilterChip(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(BuildContext context) {
    final selectedAt = _selectedAt;
    return FilterChip(
      avatar: const Icon(Icons.access_time, size: 18),
      label: Text(selectedAt != null ? _formatSelectedAt(selectedAt) : 'Time'),
      selected: selectedAt != null,
      showCheckmark: false,
      onSelected: (_) => _pickDateTime(),
      deleteIcon: selectedAt != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: selectedAt != null ? _clearSelectedTime : null,
    );
  }

  Widget _buildSchoolBusFilterChip(BuildContext context) {
    return FilterChip(
      key: _schoolBusIconKey,
      tooltip: _includeSchoolBuses ? 'Hide school buses' : 'Show school buses too',
      avatar: const Icon(Icons.school, size: 18),
      label: const Text('School buses'),
      selected: _includeSchoolBuses,
      showCheckmark: false,
      onSelected: (value) {
        setState(() => _includeSchoolBuses = value);
        _settings.setIncludeSchoolBuses(value);
      },
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

    final visibleResults = _includeSchoolBuses
        ? _results
        : _results
        .map((r) => _StopResult(
      stop: r.stop,
      departures: r.departures.where((d) => d.mode != TransportMode.schoolBus).toList(),
      error: r.error,
    ))
        .where((r) => r.departures.isNotEmpty)
        .toList();

    if (visibleResults.isEmpty) {
      return _CenteredMessage(
        icon: _includeSchoolBuses ? Icons.location_searching : Icons.school,
        message: _includeSchoolBuses
            ? 'No upcoming departures found at stops near you.'
            : 'No regular services found at stops near you right now — there may be school buses nearby (tap the school icon above to include them).',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }

    final starredResults = visibleResults.where((r) => _starredStopIds.contains(r.stop.id)).toList();
    final hasStarred = starredResults.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: visibleResults.length + (hasStarred ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasStarred && index == 0) {
            return _buildStarredSection(starredResults);
          }
          final result = visibleResults[index - (hasStarred ? 1 : 0)];
          final stopId = result.stop.id;
          return _StopCard(
            key: ValueKey(stopId),
            result: result,
            controller: _controllerFor(stopId),
            initiallyExpanded: !_collapsedStopIds.contains(stopId),
            starred: _starredStopIds.contains(stopId),
            onToggleStarred: () => _toggleStarred(stopId),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _collapsedStopIds.remove(stopId);
                } else {
                  _collapsedStopIds.add(stopId);
                }
              });
            },
          );
        },
      ),
    );
  }

  /// The pinned group of starred-and-currently-nearby stops shown at the top
  /// of the list. Collapsible on its own, separately from each stop card's
  /// own expand state, so you can quickly collapse it to skip past your
  /// stars and get straight to the regular list below.
  Widget _buildStarredSection(List<_StopResult> starredResults) {
    return Card(
      key: const ValueKey('starred-section'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _starredSectionExpanded,
        onExpansionChanged: (expanded) => setState(() => _starredSectionExpanded = expanded),
        leading: Icon(Icons.star, color: Colors.amber[700], key: _starredSectionKey),
        title: Text(
          'Starred (${starredResults.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: starredResults.map((result) {
          final stopId = result.stop.id;
          final tileId = 'starred-$stopId';
          return _StopCard(
            key: ValueKey(tileId),
            result: result,
            controller: _controllerFor(tileId),
            initiallyExpanded: !_collapsedStopIds.contains(tileId),
            starred: true,
            onToggleStarred: () => _toggleStarred(stopId),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _collapsedStopIds.remove(tileId);
                } else {
                  _collapsedStopIds.add(tileId);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final _StopResult result;
  final ExpansibleController controller;
  final bool initiallyExpanded;
  final bool starred;
  final VoidCallback onToggleStarred;
  final ValueChanged<bool> onExpansionChanged;

  const _StopCard({
    super.key,
    required this.result,
    required this.controller,
    required this.initiallyExpanded,
    required this.starred,
    required this.onToggleStarred,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stop = result.stop;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        controller: controller,
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        leading: IconButton(
          tooltip: starred ? 'Unstar this stop' : 'Star this stop',
          icon: Icon(starred ? Icons.star : Icons.star_border, color: starred ? Colors.amber[700] : null),
          onPressed: onToggleStarred,
        ),
        title: Text(stop.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: stop.distanceMetres != null ? Text('${stop.distanceMetres!.round()} m away') : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _StopMiniMap(stop: stop),
          if (result.error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(result.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )
          else
            ...result.departures.map((d) => _DepartureRow(departure: d)),
        ],
      ),
    );
  }
}

/// A small, non-interactive preview map showing where a stop is, drawn from
/// OpenStreetMap's public tiles. Only ever built while its [_StopCard] is
/// expanded (ExpansionTile doesn't build collapsed children), so a stop's
/// map tiles aren't fetched until the user actually opens that card.
class _StopMiniMap extends StatelessWidget {
  final NearbyStop stop;

  const _StopMiniMap({required this.stop});

  @override
  Widget build(BuildContext context) {
    final position = LatLng(stop.latitude, stop.longitude);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 140,
          child: IgnorePointer(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: position,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'au.org.nswtransit.nsw_transit',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: position,
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.location_on,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 4,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _SpeechBubble extends StatelessWidget {
  final String message;
  final double arrowLeftOffset;
  final VoidCallback onDismiss;

  const _SpeechBubble({
    required this.message,
    required this.arrowLeftOffset,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onDismiss,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: arrowLeftOffset),
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _TrianglePainter(color: theme.colorScheme.primaryContainer),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(message, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
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
