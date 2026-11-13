import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Thin client for the Transport for NSW Open Data Trip Planner API.
///
/// See the official Trip Planner API manual:
/// https://opendata.transport.nsw.gov.au/dataset/trip-planner-apis
///
/// Every request goes directly from this device to api.transport.nsw.gov.au
/// using an API key you register for yourself (free, at
/// opendata.transport.nsw.gov.au). This app has no backend server of its
/// own: nothing you do here is seen, logged or stored by anyone except
/// Transport for NSW and you.
class TfNswApiException implements Exception {
  final String message;
  TfNswApiException(this.message);
  @override
  String toString() => message;
}

class TfNswClient {
  static const _baseUrl = 'https://api.transport.nsw.gov.au/v1/tp/';

  final String apiKey;
  final http.Client _http;

  TfNswClient({required this.apiKey, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'apikey $apiKey',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>> _get(String call, Map<String, String> params) async {
    final uri = Uri.parse('$_baseUrl$call').replace(queryParameters: params);

    http.Response response;
    var attempt = 0;
    while (true) {
      response = await _http.get(uri, headers: _headers);
      if (response.statusCode != 429 || attempt >= 3) break;
      attempt++;
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TfNswApiException('Your API key was rejected. Check it in Settings.');
    }
    if (response.statusCode == 429) {
      throw TfNswApiException('Transport for NSW is busy right now. Try again in a moment.');
    }
    if (response.statusCode != 200) {
      throw TfNswApiException('Transport for NSW returned an error (HTTP ${response.statusCode}).');
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw TfNswApiException('Could not read the response from Transport for NSW.');
    }
  }

  /// Finds stops, stations and wharves within [radiusMetres] of the given
  /// coordinate, using the Coordinate Request API (`coord`).
  Future<List<NearbyStop>> nearbyStops({
    required double latitude,
    required double longitude,
    int radiusMetres = 1000,
  }) async {
    final coord = '${longitude.toStringAsFixed(6)}:${latitude.toStringAsFixed(6)}:EPSG:4326';
    final json = await _get('coord', {
      'outputFormat': 'rapidJSON',
      'coord': coord,
      'coordOutputFormat': 'EPSG:4326',
      'inclFilter': '1',
      'type_1': 'BUS_POINT',
      'radius_1': radiusMetres.toString(),
    });

    final locations = (json['locations'] as List?) ?? const [];
    final stops = locations
        .whereType<Map<String, dynamic>>()
        .where((l) => l['type'] == 'stop' || l['type'] == 'platform')
        .map((l) => NearbyStop.fromJson(l))
        .where((s) => s.id.isNotEmpty)
        .toList();

    // De-duplicate platforms belonging to the same parent stop ID.
    final seen = <String>{};
    final deduped = <NearbyStop>[];
    for (final stop in stops) {
      if (seen.add(stop.id)) deduped.add(stop);
    }
    deduped.sort((a, b) => (a.distanceMetres ?? 0).compareTo(b.distanceMetres ?? 0));
    return deduped;
  }

  /// Gets upcoming departures for a stop using the Departure API
  /// (`departure_mon`). Includes all modes, school buses included — the
  /// `transportation.product.class == 11` code identifies a School Bus
  /// service.
  Future<List<Departure>> departures({
    required String stopId,
    int maxResults = 12,
  }) async {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final itdDate = '${now.year}${two(now.month)}${two(now.day)}';
    final itdTime = '${two(now.hour)}${two(now.minute)}';

    final json = await _get('departure_mon', {
      'outputFormat': 'rapidJSON',
      'coordOutputFormat': 'EPSG:4326',
      'mode': 'direct',
      'type_dm': 'stop',
      'name_dm': stopId,
      'depArrMacro': 'dep',
      'itdDate': itdDate,
      'itdTime': itdTime,
      'TfNSWDM': 'true',
    });

    final stopEvents = (json['stopEvents'] as List?) ?? const [];
    final departures = stopEvents.whereType<Map<String, dynamic>>().map((e) => Departure.fromJson(e)).toList();
    departures.sort((a, b) => a.bestTime.compareTo(b.bestTime));
    if (departures.length > maxResults) {
      return departures.sublist(0, maxResults);
    }
    return departures;
  }
}
