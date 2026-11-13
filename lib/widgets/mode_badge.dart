import 'package:material_ui/material_ui.dart';

import '../core/transport_mode.dart';

class ModeBadge extends StatelessWidget {
  final TransportMode mode;
  const ModeBadge({super.key, required this.mode});

  _ModeStyle get _style {
    switch (mode) {
      case TransportMode.train:
        return _ModeStyle(Icons.train, const Color(0xFFF77D3F));
      case TransportMode.metro:
        return _ModeStyle(Icons.subway, const Color(0xFF008641));
      case TransportMode.lightRail:
        return _ModeStyle(Icons.tram, const Color(0xFFBE1719));
      case TransportMode.bus:
        return _ModeStyle(Icons.directions_bus, const Color(0xFF00A6E4));
      case TransportMode.schoolBus:
        return _ModeStyle(Icons.school, const Color(0xFFF4A81D));
      case TransportMode.coach:
        return _ModeStyle(Icons.directions_bus_filled, const Color(0xFF4B1E88));
      case TransportMode.ferry:
        return _ModeStyle(Icons.directions_boat, const Color(0xFF5BB7E4));
      case TransportMode.walk:
        return _ModeStyle(Icons.directions_walk, const Color(0xFF777777));
      case TransportMode.other:
        return _ModeStyle(Icons.commute, const Color(0xFF777777));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            mode.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.color),
          ),
        ],
      ),
    );
  }
}

class _ModeStyle {
  final IconData icon;
  final Color color;
  _ModeStyle(this.icon, this.color);
}
