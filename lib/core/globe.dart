// Orthographic projection: how the round earth looks from space. Turning the globe changes the
// centre (lon, lat); points on the far side are hidden. Pure Dart, unit-tested.
import 'dart:math';

import 'world.dart';

const _rad = pi / 180;

/// Where the globe is looking from: the point at the centre of the screen, in degrees.
class Camera {
  const Camera(this.lon, this.lat);

  final double lon;
  final double lat;

  /// Turned by a drag of (dx, dy) pixels on a globe of [radius] pixels.
  Camera dragged(double dx, double dy, double radius) {
    final perPixel = 180 / (pi * radius);
    return Camera(wrapLon(lon - dx * perPixel), (lat + dy * perPixel).clamp(-75.0, 75.0));
  }
}

double wrapLon(double lon) => (lon + 180) % 360 - 180;

/// The shortest turn from [from] to [to] longitude, so the globe never spins the long way round.
double lonDelta(double from, double to) => wrapLon(to - from);

/// A projected point: (x, y) relative to the globe's centre (y down, like the screen) and
/// whether it is on the visible side.
typedef Projected = ({double x, double y, bool visible});

Projected project(double lon, double lat, Camera v, double radius) {
  final phi = lat * _rad, lam = (lon - v.lon) * _rad, phi0 = v.lat * _rad;
  final cosC = sin(phi0) * sin(phi) + cos(phi0) * cos(phi) * cos(lam);
  return (
    x: radius * cos(phi) * sin(lam),
    y: -radius * (cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(lam)),
    visible: cosC >= 0,
  );
}

/// The (lon, lat) under a screen point (relative to the centre), or null if it misses the globe.
(double, double)? unproject(double x, double y, Camera v, double radius) {
  final rho = sqrt(x * x + y * y);
  if (rho > radius) return null;
  if (rho == 0) return (v.lon, v.lat);
  final c = asin(rho / radius), phi0 = v.lat * _rad;
  final yy = -y; // screen y points down
  final lat = asin(cos(c) * sin(phi0) + yy * sin(c) * cos(phi0) / rho);
  final lon = v.lon * _rad + atan2(x * sin(c), rho * cos(c) * cos(phi0) - yy * sin(c) * sin(phi0));
  return (wrapLon(lon / _rad), lat / _rad);
}

/// Whether (lon, lat) lies inside a ring (ray casting; rings don't cross the date line in the data).
bool insideRing(double lon, double lat, List<(double, double)> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final (xi, yi) = ring[i];
    final (xj, yj) = ring[j];
    if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

/// The country at a screen point: a tiny country if the tap is right on its marker dot, otherwise
/// the country whose shape contains the point.
Country? countryAt(World world, double x, double y, Camera v, double radius, {double markerRadius = 9}) {
  Country? nearest;
  var best = markerRadius * markerRadius;
  for (final c in world.countries.where((c) => c.tiny)) {
    final p = project(c.label.$1, c.label.$2, v, radius);
    final d = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
    if (p.visible && d <= best) {
      best = d;
      nearest = c;
    }
  }
  if (nearest != null) return nearest;
  final ll = unproject(x, y, v, radius);
  if (ll == null) return null;
  for (final c in world.countries) {
    if (c.shapes.any((ring) => insideRing(ll.$1, ll.$2, ring))) return c;
  }
  return null;
}
