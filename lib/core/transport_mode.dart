/// Transport mode, mapped from the TfNSW `transportation.product.class`
/// code returned by the Trip Planner / Departure APIs.
///
/// Reference: TfNSW Trip Planner API manual, section on route type summary
/// (class 1 = Train, 4 = Light Rail, 5 = Bus, 7 = Coach, 9 = Ferry,
/// 11 = School Bus).
enum TransportMode {
  train,
  metro,
  lightRail,
  bus,
  schoolBus,
  coach,
  ferry,
  walk,
  other,
}

TransportMode transportModeFromProductClass(int? productClass) {
  switch (productClass) {
    case 1:
      return TransportMode.train;
    case 4:
      return TransportMode.lightRail;
    case 5:
      return TransportMode.bus;
    case 11:
      return TransportMode.schoolBus;
    case 7:
      return TransportMode.coach;
    case 9:
      return TransportMode.ferry;
    case 99:
    case 100:
      return TransportMode.walk;
    default:
      return TransportMode.other;
  }
}

extension TransportModeDisplay on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.train:
        return 'Train';
      case TransportMode.metro:
        return 'Metro';
      case TransportMode.lightRail:
        return 'Light Rail';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.schoolBus:
        return 'School Bus';
      case TransportMode.coach:
        return 'Coach';
      case TransportMode.ferry:
        return 'Ferry';
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.other:
        return 'Other';
    }
  }
}
