enum DistanceStatus { safe, caution, danger, noData }

DistanceStatus classifyDistance(double? value) {
  if (value == null || !value.isFinite || value < 0) {
    return DistanceStatus.noData;
  }
  if (value < 15) return DistanceStatus.danger;
  if (value <= 30) return DistanceStatus.caution;
  return DistanceStatus.safe;
}

class DistanceReading {
  const DistanceReading(this.distance, this.receivedAt);
  final double distance;
  final DateTime receivedAt;
  factory DistanceReading.fromJson(Object? json, DateTime now) {
    if (json is! Map<String, dynamic> || json['sensor_ok'] is! bool) {
      throw const FormatException('Invalid sensor response');
    }
    if (json['sensor_ok'] != true) throw const FormatException('Sensor Error');
    final value = json['distance_cm'];
    if (value is! num ||
        classifyDistance(value.toDouble()) == DistanceStatus.noData) {
      throw const FormatException('Invalid distance reading');
    }
    return DistanceReading(value.toDouble(), now);
  }
}
