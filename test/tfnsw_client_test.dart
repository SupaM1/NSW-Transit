import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nsw_transit/core/tfnsw_client.dart';

void main() {
  group('TfNswClient.departures', () {
    test('parses a successful response into departures sorted by time', () async {
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'stopEvents': [
                {
                  'location': {'disassembledName': 'Platform 2'},
                  'departureTimePlanned': '2030-01-01T10:10:00Z',
                  'isRealtime': false,
                  'transportation': {
                    'number': '333',
                    'product': {'class': 5},
                    'destination': {'name': 'City'},
                  },
                  'properties': {},
                },
                {
                  'location': {'disassembledName': 'Platform 1'},
                  'departureTimePlanned': '2030-01-01T10:00:00Z',
                  'departureTimeEstimated': '2030-01-01T10:02:00Z',
                  'isRealtime': true,
                  'transportation': {
                    'number': 'T1',
                    'product': {'class': 1},
                    'destination': {'name': 'Central'},
                  },
                  'properties': {},
                },
              ],
            }),
            200,
          );
        }),
      );

      final departures = await client.departures(stopId: '123456');

      expect(departures, hasLength(2));
      // Sorted by bestTime: the T1 departure (10:02 estimated) comes before
      // the 333 departure (10:10 planned), even though it was listed second.
      expect(departures[0].routeName, 'T1');
      expect(departures[0].isRealtime, isTrue);
      expect(departures[0].platform, 'Platform 1');
      expect(departures[1].routeName, '333');
      expect(departures[1].destination, 'City');
    });

    test('throws a friendly message when the API key is rejected', () async {
      final client = TfNswClient(
        apiKey: 'bad-key',
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      await expectLater(
        client.departures(stopId: '123456'),
        throwsA(isA<TfNswApiException>().having((e) => e.message, 'message', contains('API key'))),
      );
    });

    test('throws a friendly message after repeated rate limiting', () async {
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async => http.Response('', 429)),
      );

      await expectLater(
        client.departures(stopId: '123456'),
        throwsA(isA<TfNswApiException>().having((e) => e.message, 'message', contains('busy'))),
      );
    });

    test('succeeds after a transient rate limit response', () async {
      var attempt = 0;
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          attempt++;
          if (attempt == 1) return http.Response('', 429);
          return http.Response(jsonEncode({'stopEvents': []}), 200);
        }),
      );

      final departures = await client.departures(stopId: '123456');

      expect(departures, isEmpty);
      expect(attempt, 2);
    });

    test('throws a generic error message for unexpected status codes', () async {
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        client.departures(stopId: '123456'),
        throwsA(isA<TfNswApiException>().having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('throws a friendly message when the response body is not valid JSON', () async {
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async => http.Response('not json', 200)),
      );

      await expectLater(client.departures(stopId: '123456'), throwsA(isA<TfNswApiException>()));
    });

    test('caps results at maxResults', () async {
      final events = List.generate(
        5,
            (i) => {
          'location': null,
          'departureTimePlanned': '2030-01-01T10:0$i:00Z',
          'isRealtime': false,
          'transportation': {
            'number': 'Route $i',
            'product': {'class': 5},
            'destination': {'name': 'Somewhere'},
          },
          'properties': {},
        },
      );

      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async => http.Response(jsonEncode({'stopEvents': events}), 200)),
      );

      final departures = await client.departures(stopId: '123456', maxResults: 2);

      expect(departures, hasLength(2));
    });

    test('sends the given date/time instead of now, formatted for the API', () async {
      late Uri requestedUri;
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(jsonEncode({'stopEvents': []}), 200);
        }),
      );

      await client.departures(stopId: '123456', at: DateTime(2030, 6, 5, 14, 30));

      expect(requestedUri.queryParameters['itdDate'], '20300605');
      expect(requestedUri.queryParameters['itdTime'], '1430');
    });
  });

  group('TfNswClient.nearbyStops', () {
    test('parses, de-duplicates and sorts stops by distance', () async {
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'locations': [
                {
                  'id': '1001',
                  'type': 'stop',
                  'name': 'Stop A',
                  'coord': [-33.87, 151.21],
                  'properties': {'distance': '120'},
                  'modes': [5],
                },
                {
                  'id': '1001',
                  'type': 'platform',
                  'name': 'Stop A Platform 1',
                  'coord': [-33.87, 151.21],
                  'properties': {'distance': '125'},
                  'modes': [5],
                },
                {
                  'id': '1002',
                  'type': 'stop',
                  'name': 'Stop B',
                  'coord': [-33.88, 151.22],
                  'properties': {'distance': '50'},
                  'modes': [1],
                },
              ],
            }),
            200,
          );
        }),
      );

      final stops = await client.nearbyStops(latitude: -33.87, longitude: 151.21);

      expect(stops, hasLength(2));
      expect(stops[0].id, '1002');
      expect(stops[0].name, 'Stop B');
      expect(stops[0].distanceMetres, 50);
      expect(stops[1].id, '1001');
      expect(stops[1].distanceMetres, 120);
    });

    test('sends the expected query parameters', () async {
      late Uri requestedUri;
      final client = TfNswClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(jsonEncode({'locations': []}), 200);
        }),
      );

      await client.nearbyStops(latitude: -33.87, longitude: 151.21, radiusMetres: 500);

      expect(requestedUri.queryParameters['radius_1'], '500');
      expect(requestedUri.queryParameters['type_1'], 'BUS_POINT');
      expect(requestedUri.queryParameters['coord'], '151.210000:-33.870000:EPSG:4326');
    });
  });
}
