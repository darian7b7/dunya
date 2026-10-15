// Geometry prepared once for fast drawing: every border point as a 3D unit vector, a coarse
// copy of each outline for when the globe is small, and a bounding cap per shape so shapes on
// the far side are skipped. Each frame then only needs multiplications, no sin/cos per point.
import 'dart:math';
import 'dart:typed_data';

import '../core/globe.dart';
import '../core/world.dart';

/// 3D unit vector for (lon, lat).
(double, double, double) unitVector(double lon, double lat) {
  final l = lon * pi / 180, p = lat * pi / 180;
  return (cos(p) * cos(l), cos(p) * sin(l), sin(p));
}

Float32List _vectors(List<(double, double)> ring) {
  final out = Float32List(ring.length * 3);
  for (var i = 0; i < ring.length; i++) {
    final (x, y, z) = unitVector(ring[i].$1, ring[i].$2);
    out[i * 3] = x;
    out[i * 3 + 1] = y;
    out[i * 3 + 2] = z;
  }
  return out;
}

/// Every [step]th point (at least 4), for drawing a small globe.
Float32List _coarse(Float32List full, int step) {
  final n = full.length ~/ 3;
  if (n <= 12) return full;
  final keep = [for (var i = 0; i < n; i += step) i];
  final out = Float32List(keep.length * 3);
  for (var k = 0; k < keep.length; k++) {
    out.setRange(k * 3, k * 3 + 3, full, keep[k] * 3);
  }
  return out;
}

class MeshShape {
  MeshShape(List<List<(double, double)>> rings)
      : full = [for (final r in rings) _vectors(r)],
        coarse = [],
        rough = [] {
    coarse.addAll([for (final r in full) _coarse(r, 3)]);
    rough.addAll([for (final r in full) _coarse(r, 6)]);
    var cx = 0.0, cy = 0.0, cz = 0.0;
    for (final r in full) {
      for (var i = 0; i < r.length; i += 3) {
        cx += r[i];
        cy += r[i + 1];
        cz += r[i + 2];
      }
    }
    final len = sqrt(cx * cx + cy * cy + cz * cz);
    if (len == 0) {
      center = (0, 0, 1);
      sinRadius = double.infinity;
      return;
    }
    center = (cx / len, cy / len, cz / len);
    var minDot = 1.0;
    for (final r in full) {
      for (var i = 0; i < r.length; i += 3) {
        minDot = min(minDot, r[i] * center.$1 + r[i + 1] * center.$2 + r[i + 2] * center.$3);
      }
    }
    // A shape reaching more than 90° from its centre is never skipped.
    sinRadius = minDot < 0 ? double.infinity : sqrt(1 - minDot * minDot);
  }

  final List<Float32List> full;
  final List<Float32List> coarse;
  final List<Float32List> rough; // for the whole globe at phone size
  late final (double, double, double) center;
  late final double sinRadius;
}

class GlobeMesh {
  GlobeMesh._(World world)
      : countries = [for (final c in world.countries) MeshShape(c.shapes)],
        land = [for (final r in world.land) MeshShape([r])],
        labels = [for (final c in world.countries) unitVector(c.label.$1, c.label.$2)],
        graticule = [
          for (var lon = -180.0; lon < 180; lon += 30) _vectors([for (var lat = -80.0; lat <= 80; lat += 4) (lon, lat)]),
          for (var lat = -60.0; lat <= 60; lat += 30) _vectors([for (var lon = -180.0; lon <= 180; lon += 4) (lon, lat)]),
        ];

  static final _cache = Expando<GlobeMesh>();

  /// Built once per world and reused.
  static GlobeMesh of(World world) => _cache[world] ??= GlobeMesh._(world);

  final List<MeshShape> countries; // same order as world.countries
  final List<MeshShape> land;
  final List<(double, double, double)> labels;
  final List<Float32List> graticule;
}

/// The camera as numbers ready for fast projection of unit vectors.
class Projector {
  Projector(Camera v, this.radius, this.cx, this.cy)
      : cl = cos(v.lon * pi / 180),
        sl = sin(v.lon * pi / 180),
        cp = cos(v.lat * pi / 180),
        sp = sin(v.lat * pi / 180);

  final double radius, cx, cy;

  /// Outlines with as much detail as this size can show.
  List<Float32List> rings(MeshShape s) => radius > 420 ? s.full : (radius > 260 ? s.coarse : s.rough);
  final double cl, sl, cp, sp;

  /// Whether any part of the shape can be on the visible side.
  bool mayBeVisible(MeshShape s) {
    final (x, y, z) = s.center;
    final dot = cp * (x * cl + y * sl) + sp * z;
    return dot >= -s.sinRadius;
  }

  /// Screen position of a unit vector, and whether it faces the viewer. Same maths as
  /// `project` in core/globe.dart, without trigonometry.
  ({double x, double y, bool visible}) point(double x, double y, double z) {
    final e = x * cl + y * sl;
    return (x: cx + radius * (y * cl - x * sl), y: cy - radius * (cp * z - sp * e), visible: sp * z + cp * e >= 0);
  }
}
