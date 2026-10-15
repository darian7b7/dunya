// The interactive 3D globe: swipe to turn (with momentum), pinch to zoom, tap a country.
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/globe.dart';
import '../core/world.dart';
import 'globe_mesh.dart';
import 'theme.dart';

/// Lets a screen turn the globe to a place.
class GlobeController {
  _GlobeViewState? _state;

  void flyTo(double lon, double lat, {double zoom = 1.6}) =>
      _state?._flyTo(lon, lat, zoom);

  /// Turns to a country and zooms in according to its size.
  void flyToCountry(Country c) =>
      flyTo(c.label.$1, c.label.$2, zoom: zoomFor(c));
}

/// Bigger countries need less zoom; tiny ones need a lot.
double zoomFor(Country c) {
  if (c.tiny) return 7;
  var minLon = 180.0, maxLon = -180.0, minLat = 90.0, maxLat = -90.0;
  for (final ring in c.shapes) {
    for (final (lon, lat) in ring) {
      minLon = min(minLon, lon);
      maxLon = max(maxLon, lon);
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
    }
  }
  final extent = max(maxLon - minLon, maxLat - minLat).clamp(1, 360);
  return (70 / extent).clamp(1.1, 6.0).toDouble();
}

class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.world,
    required this.colorOf,
    this.selected,
    this.onTap,
    this.controller,
    this.autoRotate = false,
    this.interactive = true,
    this.initial = const Camera(15, 25),
    this.lift = 0,
  });

  final World world;
  final Color Function(Country) colorOf;
  final String? selected; // ISO code of the highlighted country
  final ValueChanged<Country?>? onTap;
  final GlobeController? controller;
  final bool autoRotate;
  final bool interactive;
  final Camera initial;

  /// Moves the globe up by this many pixels, e.g. to keep the selected country above a panel.
  final double lift;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with TickerProviderStateMixin {
  late Camera _view = widget.initial;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _velocity =
      Offset.zero; // pixels per second, for momentum after a swipe
  bool _touching = false;
  double _radius = 1;

  // Fly-to animation.
  Camera? _flyFrom, _flyTarget;
  double _flyFromZoom = 1, _flyToZoom = 1;
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _fly.addListener(_onFly);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updatePulse();
      _keepMoving();
    });
  }

  /// Only animate while something moves, so a still globe costs no battery.
  void _keepMoving() {
    final needed =
        _velocity.distance > 15 ||
        (widget.autoRotate &&
            !(MediaQuery.maybeDisableAnimationsOf(context) ?? false));
    if (needed && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// The selected country glows softly; nothing to animate without a selection.
  void _updatePulse() {
    final glow = widget.selected != null && !reduceMotion(context);
    if (glow && !_pulse.isAnimating) _pulse.repeat();
    if (!glow && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void didUpdateWidget(GlobeView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    _updatePulse();
    _keepMoving();
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _ticker.dispose();
    _fly.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _flyTo(double lon, double lat, double zoom) {
    _velocity = Offset.zero;
    _flyFrom = _view;
    _flyFromZoom = _zoom;
    _flyTarget = Camera(lon, lat.clamp(-75.0, 75.0));
    _flyToZoom = zoom;
    if (reduceMotion(context)) {
      setState(() {
        _view = _flyTarget!;
        _zoom = zoom;
      });
    } else {
      _fly.forward(from: 0);
    }
  }

  void _onFly() {
    final from = _flyFrom, to = _flyTarget;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_fly.value);
    // Zoom out a little mid-flight, like a camera travelling across the globe.
    final arc = sin(t * pi) * 0.25 * min(_flyFromZoom, _flyToZoom);
    setState(() {
      _view = Camera(
        wrapLon(from.lon + lonDelta(from.lon, to.lon) * t),
        from.lat + (to.lat - from.lat) * t,
      );
      _zoom = _flyFromZoom + (_flyToZoom - _flyFromZoom) * t - arc;
    });
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1 || _touching || _fly.isAnimating) return;
    if (_velocity.distance > 15) {
      setState(() {
        _view = _view.dragged(_velocity.dx * dt, _velocity.dy * dt, _radius);
        _velocity *= pow(0.02, dt).toDouble(); // friction
      });
    } else if (widget.autoRotate && !reduceMotion(context)) {
      setState(() => _view = Camera(wrapLon(_view.lon + 5 * dt), _view.lat));
    } else {
      _velocity = Offset.zero;
      _ticker.stop(); // nothing moves any more
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.lift),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, lift, _) => _globe(lift),
    );
  }

  Widget _globe(double lift) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        _radius = min(size.width, size.height) * 0.44 * _zoom;
        final center = size.center(Offset(0, -lift));
        // Own layer: the twinkling sky and the panels don't make the globe redraw, and vice versa.
        final painter = RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: GlobePainter(
              world: widget.world,
              view: _view,
              radius: _radius,
              center: center,
              colorOf: widget.colorOf,
              selected: widget.selected,
              pulse: _pulse,
            ),
          ),
        );
        if (!widget.interactive) return painter;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) {
            _touching = true;
            _velocity = Offset.zero;
            _startZoom = _zoom;
            _fly.stop();
          },
          onScaleUpdate: (d) => setState(() {
            _view = _view.dragged(
              d.focalPointDelta.dx,
              d.focalPointDelta.dy,
              _radius,
            );
            if (d.pointerCount > 1) {
              _zoom = (_startZoom * d.scale).clamp(1.0, 12.0);
            }
          }),
          onScaleEnd: (d) {
            _touching = false;
            if (d.pointerCount == 0) _velocity = d.velocity.pixelsPerSecond;
            _keepMoving();
          },
          onTapUp: (d) {
            final p = d.localPosition - center;
            widget.onTap?.call(
              countryAt(widget.world, p.dx, p.dy, _view, _radius),
            );
          },
          child: painter,
        );
      },
    );
  }
}

class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.world,
    required this.view,
    required this.radius,
    required this.center,
    required this.colorOf,
    required this.selected,
    required this.pulse,
  }) : super(repaint: pulse);

  final World world;
  final Camera view;
  final double radius;
  final Offset center;
  final Color Function(Country) colorOf;
  final String? selected;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = center;
    final r = radius;
    final sphere = Rect.fromCircle(center: c, radius: r);

    // Atmosphere glow and the ocean, lit from the upper left.
    canvas.drawCircle(
      c,
      r * 1.1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5B8CFF).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          stops: const [0.88, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [Color(0xFF2E5AA8), ocean, oceanDeep],
          stops: [0.0, 0.55, 1.0],
        ).createShader(sphere),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    final mesh = GlobeMesh.of(world);
    final proj = Projector(view, r, c.dx, c.dy);
    _graticule(canvas, mesh, proj);

    // One path per colour instead of one per country: far fewer drawing calls.
    final land = Path();
    for (final shape in mesh.land) {
      if (proj.mayBeVisible(shape)) _addShape(land, shape, proj);
    }
    canvas.drawPath(land, Paint()..color = otherLand);

    final byColor = <Color, Path>{};
    Path? selectedPath;
    for (var i = 0; i < world.countries.length; i++) {
      final shape = mesh.countries[i];
      if (!proj.mayBeVisible(shape)) continue;
      final country = world.countries[i];
      _addShape(byColor.putIfAbsent(colorOf(country), Path.new), shape, proj);
      if (country.iso == selected) {
        _addShape(selectedPath = Path(), shape, proj);
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = nightDeep.withValues(alpha: 0.55);
    for (final e in byColor.entries) {
      canvas.drawPath(e.value, Paint()..color = e.key);
      canvas.drawPath(
        e.value,
        border,
      ); // borders: the outline of the same paths, no second copy
    }

    // Small countries also get a dot, so they can be seen and tapped.
    final dot = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < world.countries.length; i++) {
      final country = world.countries[i];
      if (!country.tiny) continue;
      final (x, y, z) = mesh.labels[i];
      final p = proj.point(x, y, z);
      if (!p.visible) continue;
      final size = country.iso == selected ? 6.0 : 3.6;
      dot.color = colorOf(country);
      canvas.drawCircle(Offset(p.x, p.y), size, dot);
      canvas.drawCircle(Offset(p.x, p.y), size, ring);
    }

    if (selectedPath != null) {
      final glow = 0.5 + 0.5 * sin(pulse.value * 2 * pi);
      canvas.drawPath(
        selectedPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = gold.withValues(alpha: 0.25 + 0.25 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        selectedPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = gold,
      );
    }
    canvas.restore();

    // Light and shadow make it look round.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.45),
          radius: 1.15,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(sphere),
    );
  }

  /// Adds a shape's outlines to [path]. Points on the far side are pushed onto the visible edge,
  /// so shapes crossing the horizon end cleanly at the rim.
  void _addShape(Path path, MeshShape shape, Projector proj) {
    for (final ring in proj.rings(shape)) {
      final n = ring.length ~/ 3;
      if (_buffer.length < n * 2) _buffer = Float32List(n * 2);
      var visible = false;
      for (var i = 0; i < n; i++) {
        final p = proj.point(ring[i * 3], ring[i * 3 + 1], ring[i * 3 + 2]);
        var x = p.x, y = p.y;
        if (p.visible) {
          visible = true;
        } else {
          final dx = x - proj.cx, dy = y - proj.cy;
          final d = sqrt(dx * dx + dy * dy);
          if (d > 0) {
            x = proj.cx + dx / d * proj.radius;
            y = proj.cy + dy / d * proj.radius;
          }
        }
        _buffer[i * 2] = x;
        _buffer[i * 2 + 1] = y;
      }
      if (!visible) continue; // entirely behind the globe
      path.moveTo(_buffer[0], _buffer[1]);
      for (var i = 1; i < n; i++) {
        path.lineTo(_buffer[i * 2], _buffer[i * 2 + 1]);
      }
      path.close();
    }
  }

  static Float32List _buffer = Float32List(2048);

  void _graticule(Canvas canvas, GlobeMesh mesh, Projector proj) {
    final path = Path();
    for (final line in mesh.graticule) {
      var drawing = false;
      for (var i = 0; i < line.length; i += 3) {
        final p = proj.point(line[i], line[i + 1], line[i + 2]);
        if (!p.visible) {
          drawing = false;
          continue;
        }
        drawing ? path.lineTo(p.x, p.y) : path.moveTo(p.x, p.y);
        drawing = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(GlobePainter old) =>
      old.view.lon != view.lon ||
      old.view.lat != view.lat ||
      old.radius != radius ||
      old.center != center ||
      old.selected != selected ||
      old.colorOf != colorOf;
}
