import 'transport_mode.dart';

class NearbyStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? distanceMetres;
  final List<TransportMode> modes;

  NearbyStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMetres,
    required this.modes,
  });

  factory NearbyStop.fromJson(Map<String, dynamic> json) {
    final coord = (json['coord'] as List?) ?? const [];
    final modesRaw = (json['modes'] as List?) ?? const [];
    final properties = json['properties'] as Map<String, dynamic>?;
    final distanceStr = properties?['distance'];
    return NearbyStop(
      id: json['id']?.toString() ?? json['stateless']?.toString() ?? '',
      name: json['name']?.toString() ?? json['disassembledName']?.toString() ?? 'Unknown stop',
      latitude: coord.isNotEmpty ? (coord[0] as num).toDouble() : 0,
      longitude: coord.length > 1 ? (coord[1] as num).toDouble() : 0,
      distanceMetres: distanceStr != null ? double.tryParse(distanceStr.toString()) : null,
      modes: modesRaw.map((m) => transportModeFromProductClass(m is int ? m : int.tryParse(m.toString()))).toList(),
    );
  }
}

class Departure {
  final String routeName;
  final String destination;
  final DateTime plannedTime;
  final DateTime? estimatedTime;
  final TransportMode mode;
  final bool isRealtime;
  final bool isCancelled;
  final String? platform;

  Departure({
    required this.routeName,
    required this.destination,
    required this.plannedTime,
    required this.estimatedTime,
    required this.mode,
    required this.isRealtime,
    required this.isCancelled,
    required this.platform,
  });

  DateTime get bestTime => estimatedTime ?? plannedTime;

  factory Departure.fromJson(Map<String, dynamic> json) {
    final transportation = json['transportation'] as Map<String, dynamic>? ?? const {};
    final product = transportation['product'] as Map<String, dynamic>? ?? const {};
    final destination = transportation['destination'] as Map<String, dynamic>?;
    final location = json['location'] as Map<String, dynamic>?;
    final properties = json['properties'] as Map<String, dynamic>?;

    final plannedRaw = json['departureTimePlanned'] ?? json['arrivalTimePlanned'];
    final estimatedRaw = json['departureTimeEstimated'] ?? json['arrivalTimeEstimated'];

    return Departure(
      routeName: transportation['number']?.toString() ??
          transportation['disassembledName']?.toString() ??
          transportation['name']?.toString() ??
          '',
      destination: destination?['name']?.toString() ?? 'Unknown destination',
      plannedTime: plannedRaw != null ? DateTime.parse(plannedRaw.toString()).toLocal() : DateTime.now(),
      estimatedTime: estimatedRaw != null ? DateTime.parse(estimatedRaw.toString()).toLocal() : null,
      mode: transportModeFromProductClass(product['class'] is int ? product['class'] as int : int.tryParse(product['class']?.toString() ?? '')),
      isRealtime: json['isRealtime'] == true,
      isCancelled: properties?['realtimeTripStatus']?.toString().toUpperCase().contains('CANCELLED') == true ||
          properties?['cancelled'] == true,
      platform: location?['disassembledName']?.toString(),
    );
  }
}
